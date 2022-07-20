%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_sub
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address, library_call

from src.interfaces.ISolver import ISolver
from src.interfaces.ISolver_registry import ISolver_registry
from src.interfaces.IERC20 import IERC20

from src.openzeppelin.access.ownable import Ownable
from src.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from src.openzeppelin.security.safemath import SafeUint256
from src.lib.hub import Hub, multi_call_selector, Hub_router_type

#
#Storage
#

@storage_var
func trade_executor() -> (trade_executor_address: felt):
end

@storage_var
func Hub_solver_registry() -> (registry_address : felt):
end

#
#Views
#

@view
func solver_registry{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (solver_registry: felt):
    let (solver_registry) = Hub.solver_registry()
    return(solver_registry)
end

@view
func get_contract_caller{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (caller: felt):
    let (caller) = get_caller_address()
    return(caller)
end

#
#Constructor
#

@constructor
func constructor{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    let (owner) = get_caller_address()
    Ownable.initializer(owner)
    return()
end

#
#Externals
#

@external
func swap_with_solver{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    _token_in : felt, 
    _token_out : felt, 
    _amount_in : Uint256, 
    _min_amount_out : Uint256, 
    _solver_id : felt)->(received_amount: Uint256, router_address: felt):

    alloc_locals

    ReentrancyGuard._start()

    #Get Solver address that will be used
    let (solver_registry) = Hub.solver_registry()
    let (local solver_address) = ISolver_registry.get_solver(solver_registry,_solver_id)
    with_attr error_message(
        "solver ID invalid"):
        assert_not_equal(solver_address,FALSE)
    end

    #Get Caller Address
    let (caller_address) = get_caller_address()
    #Get Hub Address
    let (this_address) = get_contract_address()
    #Send tokens_in to the hub
    IERC20.transferFrom(_token_in,caller_address,this_address,_amount_in)

    #Check current token balance
    #(Used to determine received amount)
    let(original_balance: Uint256) = IERC20.balanceOf(_token_out,this_address) 

    #Get trading path from the selected solver
    let (routers_len : felt,
        routers : felt*,
        tokens_in_len : felt, 
        tokens_in : felt*,
        tokens_out_len : felt, 
        tokens_out : felt*,
        amounts_len : felt, 
        amounts : felt*, 
        _
    ) = ISolver.get_results(solver_address, _amount_in, _token_in, _token_out)

    #Delegate Call: Execute transactions
    let (trade_executor_hash) = trade_executor.read()
    let (calldata : felt*) = alloc()

    assert calldata[0] = _amount_in.low
    assert calldata[1] = _amount_in.high
    assert calldata[2] = routers_len
    memcpy(calldata, routers, routers_len)
    memcpy(calldata, tokens_in, tokens_in_len)
    memcpy(calldata, tokens_out, tokens_out_len)
    library_call(
        trade_executor_hash,
        multi_call_selector,
        routers_len+tokens_in_len+tokens_out_len+3,
        calldata,
    )
    
    #Check received Amount
    #We do not naively transfer out the entire balance of that token, as there hub might be holding more
    #tokens that it received as rewards or that where mistakenly sent here
    let (new_amount: Uint256) = IERC20.balanceOf(_token_out,this_address) 
    let (received_amount: Uint256) = SafeUint256.sub_le(new_amount,original_balance)

    #Check that tokens received by solver at at least as much as the min_amount_out
    let (min_amount_received) = uint256_le(_min_amount_out,received_amount)
    with_attr error_message(
        "Minimum amount not received"):
        assert min_amount_received = TRUE
    end
    

    #Transfer _token_out back to caller
    IERC20.transfer(_token_out,caller_address,received_amount)

    ReentrancyGuard._end()

    return (Uint256(0,0), 0)
end

@external
func swap_with_path{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    routers_len : felt,
    routers : felt*,
    tokens_in_len : felt, 
    tokens_in : felt*, 
    tokens_out_len : felt, 
    tokens_out : felt*, 
    _amount_in : Uint256, 
    _min_amount_out : Uint256):
    alloc_locals

    ReentrancyGuard._start()

    #Get Caller Address
    let (caller_address) = get_caller_address()

    let (this_address) = get_contract_address()

    let(original_balance: Uint256) = IERC20.balanceOf(tokens_out[tokens_out_len-1],this_address) 

    #Delegate Call: Execute transactions
    let (trade_executor_hash) = trade_executor.read()
    let (calldata : felt*) = alloc()
    let (calldata : felt*) = alloc()

    assert calldata[0] = _amount_in.low
    assert calldata[1] = _amount_in.high
    assert calldata[2] = routers_len
    memcpy(calldata, routers, routers_len)
    assert calldata[2+routers_len] = tokens_in_len
    memcpy(calldata, tokens_in, tokens_in_len)
    assert calldata[2+routers_len+tokens_in_len] = tokens_out_len
    memcpy(calldata, tokens_out, tokens_out_len)
    library_call(
        trade_executor_hash,
        multi_call_selector,
        routers_len+tokens_in_len+tokens_out_len+2,
        calldata,
    )
    
    #Get new Balance of out_token
    let (new_amount: Uint256) = IERC20.balanceOf(tokens_out[tokens_out_len-1],this_address) 
    #ToDo: underlflow check
    let (received_amount: Uint256) = SafeUint256.sub_le(new_amount,original_balance)

    #Check that tokens received by solver at at least as much as the min_amount_out
    let (min_amount_received) = uint256_le(_min_amount_out,received_amount)
    assert min_amount_received = TRUE

    #Transfer _token_out back to caller
    IERC20.transfer(tokens_out[tokens_out_len-1],caller_address,received_amount)

    ReentrancyGuard._end()

    return()
end

#
#Admin functions
#

@external
func set_solver_registry{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_registry: felt) -> ():
    Ownable.assert_only_owner()
    Hub.set_solver_registry(_new_registry)
    return()
end

@external
func set_router_type{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _router_type: felt, _router_address: felt) -> ():
    Ownable.assert_only_owner()
    Hub.set_router_type(_router_type, _router_address)
    return()
end

@external
func retrieve_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _token_len: felt, _token: felt*, _token_amount_len: felt, _token_amount: Uint256*) -> ():
    Ownable.assert_only_owner()
    return()
end

@external
func set_executor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _executor_hash: felt):
    Ownable.assert_only_owner()
    trade_executor.write(_executor_hash)
    return()
end