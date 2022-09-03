%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from src.openzeppelin.security.safemath import SafeUint256
from src.lib.hub import Uni
from src.lib.utils import Utils, Router, Path
from src.lib.constants import BASE

from src.interfaces.IERC20 import IERC20
from src.interfaces.IUni_router import IUni_router
const trade_deadline = 2644328911 # Might want to increase this or make a parameter

@view
func simulate_multi_swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _routers_len : felt,
        _routers: Router*,
        _path_len : felt,
        _path : Path*,
        _amounts_len : felt,
        _amounts : felt*,
        _amount_in: Uint256
    )->(amount_out: Uint256):
    alloc_locals

    if _routers_len == 0 :
        return(_amount_in)
    end

    let (trade_amount) = Utils.fmul(_amount_in,Uint256(_amounts[0],0),Uint256(BASE,0))

    let (amount_out: Uint256) = simulate_swap(_routers[0],trade_amount,_path[0].token_in,_path[0].token_out)
    
    let (final_amount_out) = simulate_multi_swap(
        _routers_len-1,
        _routers+2,
        _path_len,
        _path+2,
        _amounts_len,
        _amounts+1,
        amount_out
    )

    return(final_amount_out)
end

@external
func multi_swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _routers_len : felt,
        _routers: Router*,
        _path_len : felt,
        _path : Path*,
        _amounts_len : felt,
        _amounts : felt*,
        _receiver_address: felt,
        _amount_in: Uint256
    ):
    alloc_locals

    if _routers_len == 0 :
        return()
    end
    
    let (local amount_before_trade: Uint256) = IERC20.balanceOf(_path[0].token_out,_receiver_address)
    
    let (trade_amount) = Utils.fmul(_amount_in,Uint256(_amounts[0],0),Uint256(BASE,0))

    _swap(_routers[0],trade_amount,_path[0].token_in,_path[0].token_out,_receiver_address)

    let (amount_after_trade: Uint256) = IERC20.balanceOf(_path[0].token_out,_receiver_address)

    let (new_token_amount: Uint256) = SafeUint256.sub_le(amount_after_trade,amount_before_trade)
    
    multi_swap(
        _routers_len-1,
        _routers+2,
        _path_len,
        _path+2,
        _amounts_len,
        _amounts+1,
        _receiver_address,
        new_token_amount
    )
    
    return()
end

func _swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _router: Router,
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _receiver_address: felt
    ): 

    if _router.type == Uni :
        IERC20.approve(_token_in,_router.address,_amount_in)
        let (path : felt*) = alloc()
        assert path[0] = _token_in
        assert path[1] = _token_out
        IUni_router.swap_exact_tokens_for_tokens(_router.address,_amount_in,Uint256(0,0),2,path,_receiver_address,trade_deadline)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr    
    else:
        with_attr error_message("TRADE EXECUTIONER: Router type doesn't exist"):
            assert 1 = 2
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    
    #if router_type == Cow :
    #    ICoW.deposit(_router_address,amount)
    #	ICoW.balance() :
    #end

    return()
end

func simulate_swap{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        _router: Router,
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt
    )->(amount_out: Uint256): 

    if _router.type == Uni :
        let (path : felt*) = alloc()
        assert path[0] = _token_in
        assert path[1] = _token_out
        let (amounts_len: felt, amounts: Uint256*) = IUni_router.get_amounts_out(_router.address,_amount_in, 2, path) 
        return(amounts[1]) 
    else:
        with_attr error_message("TRADE EXECUTIONER: Router type doesn't exist"):
            assert 1 = 2
        end
        return(Uint256(0,0))
    end
    
    #if router_type == Cow :
    #    ICoW.deposit(_router_address,amount)
    #	ICoW.balance() :
    #end
end