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
from src.interfaces.ITrade_executioner import ITrade_executioner
from src.interfaces.IERC20 import IERC20

from src.openzeppelin.access.ownable import Ownable
from src.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from src.openzeppelin.security.safemath import SafeUint256
from src.lib.hub import Hub, multi_call_selector, simulate_multi_swap_selector, Hub_trade_executor, Hub_solver_registry
from src.lib.arrayV2 import Array

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
func get_solver_result{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(_amount_in: Uint256, _token_in: felt, _token_out: felt, _solver_id: felt)->(amount_out: Uint256):
    alloc_locals

    let (solver_registry) = Hub.solver_registry()
    let (local solver_address) = ISolver_registry.get_solver(solver_registry,_solver_id)
    with_attr error_message("solver ID invalid"):
        assert_not_equal(solver_address,FALSE)
    end

    #Get trading path from the selected solver
    let (router_addresses_len : felt,
        router_addresses : felt*,
        router_types_len : felt,
        router_types : felt*,
        path_len : felt, 
        path : felt*,
        amounts_len : felt, 
        amounts : felt*
    ) = ISolver.get_results(solver_address, _amount_in, _token_in, _token_out)

    let (trade_executor_hash) = Hub_trade_executor.read()

    #Execute Trades
    let (amount_out: Uint256) = ITrade_executioner.library_call_simulate_multi_swap(
        trade_executor_hash,
        router_addresses_len,
        router_addresses,
        router_types_len,
        router_types,
        path_len,
        path,
        amounts_len,
        amounts,
        _amount_in
    )

    return(amount_out)
end

#UniSwap Conform function
@view
func get_amounts_out{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    return()
end

#
#Constructor
#

@constructor
func constructor{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(_owner: felt):
    Ownable.initializer(_owner)
    return()
end

#
#Externals
#

#Uniswap Conform function
@external
func swap_exact_tokens_for_tokens{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    amountIn: Uint256, 
    amountOutMin: Uint256, 
    path_len: felt, 
    path: felt*, 
    to: felt, 
    deadline: felt) -> (amounts_len: felt, amounts: Uint256*):
    alloc_locals

    #Check that deadline hasn't past

    #Check that the proposed trade is only between two tokens
    assert path_len = 2

    let (received_amount: Uint256) = swap_with_solver(path[0],path[1],amountIn,amountOutMin,to,1)
    let (uint256_pointer: Uint256*) = alloc()
    assert uint256_pointer[0] = received_amount
    
    return(1, uint256_pointer)
end    


#TODO: ADD UNIV2 CONFORM FUNCTION THAT USES SOLVER 1 AS A DEFAULT???
@external
func swap_with_solver{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    _token_in : felt, 
    _token_out : felt, 
    _amount_in : Uint256, 
    _min_amount_out : Uint256,
    _to : felt,
    _solver_id : felt)->(received_amount: Uint256):

    let (received_amount: Uint256) = Hub.swap_with_solver(_token_in,_token_out,_amount_in,_min_amount_out,_to,_solver_id)

    return (received_amount)
end

@external
func swap_with_path{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(
    _router_addresses_len: felt,
    _router_addresses: felt*,
    _router_types_len: felt,
    _router_types: felt*,
    _path_len: felt,
    _path: felt*,
    _amounts_len: felt,
    _amounts: felt*,
    _amount_in : Uint256, 
    _min_amount_out : Uint256):
    alloc_locals

    ReentrancyGuard._start()

    #Get Caller Address
    let (caller_address) = get_caller_address()

    let (this_address) = get_contract_address()

    let(original_balance: Uint256) = IERC20.balanceOf(_path[_path_len-1],this_address) 

    #Delegate Call: Execute transactions
    let (trade_executor_hash) = Hub_trade_executor.read()

    #Execute Trades
    ITrade_executioner.library_call_multi_swap(
        trade_executor_hash,
        _router_addresses_len,
        _router_addresses,
        _router_types_len,
        _router_types,
        _path_len,
        _path,
        _amounts_len,
        _amounts,
        this_address,
        _amount_in
    )
    
    #Get new Balance of out_token
    let (new_amount: Uint256) = IERC20.balanceOf(_path[_path_len-1],this_address) 
    #ToDo: underlflow check
    let (received_amount: Uint256) = SafeUint256.sub_le(new_amount,original_balance)

    #Check that tokens received by solver at at least as much as the min_amount_out
    let (min_amount_received) = uint256_le(_min_amount_out,received_amount)
    assert min_amount_received = TRUE

    #Transfer _token_out back to caller
    IERC20.transfer(_path[_path_len-1],caller_address,received_amount)

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
    Hub_trade_executor.write(_executor_hash)
    return()
end