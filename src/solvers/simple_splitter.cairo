%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.utils import Router
from src.interfaces.IERC20 import IERC20
from src.lib.constants import BASE

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
        _path_len : felt, 
        _path : felt*,
        amounts_len : felt, 
        amounts : felt*
    ):
    alloc_locals
    
    let (router_aggregator_address) = router_aggregator.read()

    let (
        amounts_out_len: felt,
        amounts_out: Uint256*,
        routers_len: felt,  
        routers: Router*
    ) = IRouter_aggregator.get_all_routers(router_aggregator_address, _amount_in, _token_in, _token_out)

    let (sum: Uint256) = sum_amounts(amounts_out_len,amounts_out)

    let () = determine_share_and_kick(sum,amounts_out,routers)
    
    return(1,router_addresses,1,router_types,2,path,1,amounts)
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
    }(amounts_out_len: felt, amounts_out Uint256*):

    if amounts_out_len == 0:
        return (0)
    end

    let (sum: Uint256) = sum_amounts(amounts_out_len-1,amounts_out+1)

    return(amounts_out[0]+sum)
end

func array_sum(arr : felt*, size) -> (sum : felt):
    

    # size is not zero.
    let (sum_of_rest) = array_sum(arr=arr + 1, size=size - 1)
    return (sum=[arr] + sum_of_rest)
end