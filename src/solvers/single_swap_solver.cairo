%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import (get_contract_address)
from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.ITrade_executor import ITrade_executor
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

@storage_var
func trade_executor() -> (trade_executor_address: felt):
end

@external 
func execute_solver{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256,
    _token_in: felt,
    _token_out: felt,
    _receiver: felt)
    -> (amount_out: Uint256):
    
    let (router_aggregator_address) = router_aggregator.read()
    let (trade_executor_address) = trade_executor.read()

    let (amount_out: Uint256, router_address: felt,_) = IRouter_aggregator.get_single_best_pool(router_aggregator_address,_amount_in,_token_in,_token_out)

    IERC20.transfer(_token_in,trade_executor_address,_amount_in)
    ITrade_executor.swap_single(trade_executor_address,router_address,_amount_in,_token_in,_token_out,_receiver)

    return(amount_out)
end

@view
func get_results{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,range_check_ptr}(
    _amount_in: Uint256,
    _token_in: felt,
    _token_out: felt)
    -> (
    return_amount: Uint256):
    
    let (router_aggregator_address) = router_aggregator.read()

    let (amount_out,_,_) = IRouter_aggregator.get_single_best_pool(router_aggregator_address,_amount_in,_token_in,_token_out)

    return(amount_out)
end

#
#Admin
#

@external
func set_executor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _executor: felt):
    #Only Admin
    trade_executor.write(_executor)
    return()
end

@external
func set_router_aggregator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _router_aggregator: felt):
    router_aggregator.write(_router_aggregator)
    return()
end
