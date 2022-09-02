%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le_felt

from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.utils import Router, Liquidity, Path
from src.interfaces.IERC20 import IERC20
from src.lib.constants import BASE

const threshold = 100000000000000000 # 1e17

#This should be a const, but easier like this for testing   
@storage_var
func router_aggregator() -> (router_aggregator_address: felt):
end

@view
func get_results{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt
    )->(
        routers_len : felt,
        routers : Router*,
        path_len : felt, 
        path : Path*,
        amounts_len : felt, 
        amounts : felt*
    ):
    alloc_locals

    let (amounts : felt*) = alloc()
    let (final_routers : Router*) = alloc()
    let (final_liquidity : Liquidity*) = alloc()
    let (path : Path) = alloc()
    
    let (router_aggregator_address) = router_aggregator.read()

    let (
        liquidity_len: felt,
        liquidity: Liquidity*,
        routers_len: felt,  
        routers: Router*
    ) = IRouter_aggregator.get_all_routers_and_liquidity(router_aggregator_address, _token_in, _token_out)

    let (sum: Uint256) = sum_amounts(liquidity_len,liquidity)

    let (final_routers_len: felt) = kick_low_liquidity(sum.low,final_routers,routers,final_liquidity,liquidity)

    let (final_sum: Uint256) = sum_amounts(liquidity_len,final_liquidity)

    set_amounts(final_sum,final_routers_len,final_liquidity)

    set_path(final_routers_len,path,_token_in,_token_out)
    
    return(
        routers_len=final_routers_len,
        routers=routers,
        path_len=final_routers_len,
        path=path,
        amounts_len=final_routers_len,
        amounts=amounts
    )
end

#
#Admin
#

@external
func set_router_aggregator{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(_router_aggregator: felt):
    router_aggregator.write(_router_aggregator)
    return()
end

#
# Internals
#

func sum_amounts{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(liquidity_len: felt, liquidity Liquidity*):

    if amounts_out_len == 0:
        return (0)
    end

    let (sum: Uint256) = sum_amounts(liquidity_len-1,liquidity+4)
    let (addition: Uint256) = uint256(liquidity[0].out,sum)
    return(addition)
end

func kick_low_liquidity{pedersen_ptr : HashBuiltin*}(
        _sum : felt,
        _routers_len: felt,
        _final_routers: Router*,
        _routers: Router*,
        _final_liquidity: felt*,
        _liquidity: felt*
    )->(_routers_len: felt):
    alloc_locals

    if _amounts_out_len == 0 :
        return(_routers_len,_final_routers,_final_liquidity)
    end

    local based_liquidity = _liquidity[0] * BASE
    let (local share,_) = unsigned_div_rem(based_liquidity,_sum)
    let (is_below_threshold) = is_le_felt(share,threshold)

    if is_below_threshold == TRUE:
        determine_share_and_kick(_sum,_routers_len,_final_routers,_routers+2,_final_liquidity,_liquidity+1)
        return(_routers_len)
    else:
        assert _final_routers[0] = _routers[0]
        assert _final_liquidity[0] = _liquidity[0]
        determine_share_and_kick(_sum,_routers_len-1,_final_routers+2,_routers+2,_final_liquidity+1,_liquidity+1)
        return(_routers_len)
    end
end

func set_path{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(path_len: felt,path: Path*,token_in: felt,token_out: felt):
    if path_len == 0:
        return()
    end

    assert path[0] = Path(token_in,token_out)

    set_path(path_len-1,path+2,token_in,token_out)
    return()
end