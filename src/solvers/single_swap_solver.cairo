%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import (get_contract_address)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.IERC20 import IERC20

###################################################################################
#                                                                                 #  
#   THIS IS THE SIMPLEST AND MOST FLEXIBLE SOLVER FOR INTEGRATION WITH PROTOCOLS  #
#                                                                                 #  
###################################################################################

#This should be a const, but easier like this for testing   
@storage_var
func router_aggregator() -> (router_aggregator_address: felt):
end

@view
func get_results{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,range_check_ptr}(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt
    )-> (
        router_addresses_len : felt,
        router_addresses : felt*,
        router_types_len : felt,
        router_types : felt*,
        tokens_in_len : felt, 
        tokens_in : felt*,
        tokens_out_len : felt, 
        tokens_out : felt*,
        amounts_len : felt, 
        amounts : Uint256*, 
        amount_out: Uint256 
    ):
    alloc_locals
    
    let (router_aggregator_address) = router_aggregator.read()

    let (amount_out,router_address,router_type) = IRouter_aggregator.get_single_best_pool(router_aggregator_address,_amount_in,_token_in,_token_out)

    let (router_addresses : felt*) = alloc()
    let (router_types : felt*) = alloc()
    let (tokens_in : felt*) = alloc()
    let (tokens_out : felt*) = alloc()
    let (amounts : Uint256*) = alloc()
    
    assert router_addresses[0] = router_address
    assert router_types[0] = router_type
    assert tokens_in[0] = _token_in
    assert tokens_out[0] = _token_out
    assert amounts[0] = _amount_in

    return(1,router_addresses,1,router_types,1,tokens_in,1,tokens_out,1,amounts,amount_out)
end

#
#Admin
#

@external
func set_router_aggregator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _router_aggregator: felt):
    router_aggregator.write(_router_aggregator)
    return()
end
