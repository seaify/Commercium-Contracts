%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_sub
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_equal
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from src.interfaces.ISolver import ISolver
from src.interfaces.ITrade_executor import ITrade_executor
from src.interfaces.ISolver_registry import ISolver_registry
from src.interfaces.IERC20 import IERC20

from src.openzeppelin.access.ownable import Ownable
from src.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from src.lib.hub import Hub


struct Swap:
    member token_in: felt
    member token_out: felt
    member router: felt
end

#
#Storage
#

@storage_var
func trade_executor() -> (trade_executor_address: felt):
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
#    let (owner) = get_caller_address()
#    Ownable.initializer(owner)
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
    _solver_id : felt):

    alloc_locals

    ReentrancyGuard._start()

    #Get Solver address that will be used
    let (solver_registry) = Hub.solver_registry()
    let (local solver_address) = ISolver_registry.get_solver(solver_registry,_solver_id)
    assert_not_equal(solver_address,FALSE)

    #Get Caller Address
    let (caller_address) = get_caller_address()
    #Get Hub Address
    let (this_address) = get_contract_address()

    #Check current token balance
    #(Used to determine received amount)
    let(original_balance: Uint256) = IERC20.balanceOf(_token_out,this_address) 

    #transfer tokens to the solver contract
    IERC20.transferFrom(_token_in,caller_address,solver_address,_amount_in) 
    
    #Execute solver logic
    ISolver.execute_solver(solver_address, _amount_in, _token_in, _token_out, this_address)
    
    #Check received Amount
    #We do not naively transfer out the entire balance of that token, as there hub might be holding more
    #tokens that it received as rewards or that where mistakenly sent here
    let (new_amount: Uint256) = IERC20.balanceOf(_token_out,this_address) 
    #ToDo: underlflow check
    let (received_amount: Uint256) = uint256_sub(new_amount,original_balance)

    #Check that tokens received by solver at at least as much as the min_amount_out
    let (min_amount_received) = uint256_le(_min_amount_out,received_amount)
    assert min_amount_received = TRUE

    #Transfer _token_out back to caller
    IERC20.transfer(_token_out,caller_address,received_amount)

    ReentrancyGuard._end()

    return ()
end

@external
func swap_with_path{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    _path_len: felt,
    _path: Swap*, 
    _amount_in : Uint256, 
    _min_amount_out : Uint256):
    alloc_locals

    ReentrancyGuard._start()

    #Get Caller Address
    let (caller_address) = get_caller_address()

    let (this_address) = get_contract_address()

    let(original_balance: Uint256) = IERC20.balanceOf(_token_out,this_address) 

    let (trade_executor_address) = trade_executor.read()

    #transfer tokens to the solver contract
    IERC20.transferFrom(_path[0].token_in,caller_address,trade_executor_address,_amount_in) 

    ITrade_executor.multis_swap(trade_executor_address,_path_len,_path,trade_executor_address,this_address)
    
    let (new_amount: Uint256) = IERC20.balanceOf(_token_out,this_address) 
    #ToDo: underlflow check
    let (received_amount: Uint256) = uint256_sub(new_amount,original_balance)

    #Check that tokens received by solver at at least as much as the min_amount_out
    let (min_amount_received) = uint256_le(_min_amount_out,received_amount)
    assert min_amount_received = TRUE

    #Transfer _token_out back to caller
    IERC20.transfer(_token_out,caller_address,received_amount)

    ReentrancyGuard._end()

    return()
end

#
#Admin functions
#

@external
func set_registry{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _new_registry: felt) -> ():
    #Ownable.assert_only_owner()
    Hub.set_registry(_new_registry)
    return()
end

@external
func retrieve_tokens{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _token_len: felt, _token: felt*, _token_amount_len: felt, _token_amount: Uint256*) -> ():
    #Ownable.assert_only_owner()
    return()
end

@external
func set_executor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _executor: felt):
    #Only Admin
    trade_executor.write(_executor)
    return()
end


