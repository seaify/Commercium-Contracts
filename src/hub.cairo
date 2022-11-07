// SPDX-License-Identifier: MIT
/// @title Main contract that acts as a security layer and the main contact point for any trader/protocol utilizing the Commercium. 
/// @author FreshPizza

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.starknet.common.syscalls import (
    get_contract_address,
    get_caller_address,
    library_call,
)

from src.interfaces.i_trade_executor import ITradeExecutor
from src.interfaces.i_erc20 import IERC20

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.security.reentrancyguard.library import ReentrancyGuard
from openzeppelin.security.safemath.library import SafeUint256
from src.lib.utils import Router, Path
from src.lib.hub import Hub, Hub_trade_executor

//
// Events
//

@event
func swap_executed(solver_used: felt, amount_traded: Uint256) {
}

/////////////////////////////
//       Constructor       //
/////////////////////////////

//@notice initialize the HUB contract
//@param _owner - The initial owner of the Hub contract
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_owner: felt) {
    Ownable.initializer(_owner);
    return ();
}

////////////////////////
//       Views        //
////////////////////////

// @notice get the address of the utilized solver registry
// @return solver registry address
@view
func solver_registry{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (solver_registry: felt) {
    let (solver_registry) = Hub.solver_registry();
    return (solver_registry,);
}

// @notice get the contract hash of the utilized trade executor
// @return trade executor hash
@view
func trade_executor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (trade_executor: felt) {
    let (trade_executor) = Hub.trade_executor();
    return (trade_executor,);
}

// @notice Use this function to receive the token amount that would be returned given a specific trade and solver 
// @param _amount_in the number of tokens that are supposed to be sold
// @param _token_in the address of the token that would be sold
// @param _token_out the address of the token that would be bought
// @param _solver_id the id of the solver/algorithm that will be used to dertermine the trading route 
// @return amount_out the number of _token_out that would be received if this trade was executed
@view
func get_amount_out_with_solver{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt, 
        _solver_id: felt
    ) -> (amount_out: Uint256) {
    let (amount_out) = Hub.get_solver_amount(_amount_in, _token_in, _token_out, _solver_id);

    return (amount_out=amount_out);
}

// @notice Use this function to receive the token amount and trading route that would be returned given a specific trade and solver 
// @param _amount_in - The number of tokens that are supposed to be sold
// @param _token_in - The address of the token that would be sold
// @param _token_out - The address of the token that would be bought
// @param _solver_id - The id of the solver/algorithm that will be used to dertermine the trading route 
// @return routers - The router address and router type that would be used for each trading step
// @return path - The token address of the token being sold and bought for each trading step
// @return amounts - The amount of tokens (in %) sold for each trading step 
// @return amount_out - The number of _token_out that would be received if this trade was executed
@view
func get_amount_and_path_with_solver{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt, 
        _solver_id: felt
    ) -> (
        routers_len: felt,
        routers: Router*,
        path_len: felt,
        path: Path*,
        amounts_len: felt,
        amounts: felt*,
        amount_out: Uint256,
    ){
    let (
        routers_len: felt,
        routers: Router*,
        path_len: felt,
        path: Path*,
        amounts_len: felt,
        amounts: felt*,
        amount_out: Uint256,
    ) = Hub.get_solver_amount_and_path(_amount_in, _token_in, _token_out, _solver_id);

    return (routers_len, routers, path_len, path, amounts_len, amounts, amount_out);
}

// @notice This function returns the expected return amount for a given trade when using the default solver
// @param _amount_in - The number of tokens that are supposed to be sold
// @param _token_in - The address of the token that would be sold
// @param _token_out - The address of the token that would be bought
// @return amount - The estimated amount of tokens received 
@view
func get_amount_out{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256, 
        _token_in: felt,
        _token_out: felt
    ) -> (amount: Uint256) {

    let (amount_out) = Hub.get_solver_amount(
        _amount_in=_amount_in, _token_in=_token_in, _token_out=_token_out, _solver_id=1
    );

    return (amount_out,);
}

// @notice Receive multiple solver results with one query
// @param _amount_in - The number of tokens that are supposed to be sold
// @param _token_in - The address of the token that would be sold
// @param _token_out - The address of the token that would be bought
// @param _solver_ids_ - The IDs of the solvers to be used for the different trades
// @return amounts_out - An array of tokens returned by each solver
@view 
func get_multiple_solver_amounts{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt, 
        _solver_ids_len: felt,
        _solver_ids: felt*
    ) -> (amounts_out_len: felt, amounts_out: Uint256*) {
    alloc_locals;

    let (amounts_out: Uint256*) = alloc();

    Hub.get_multiple_solver_amounts(_amount_in, _token_in, _token_out, _solver_ids_len, _solver_ids, amounts_out);

    return (_solver_ids_len, amounts_out);
}


////////////////////////////
//       Externals        //
////////////////////////////

// @notice Swap an exact amount of a token for largest possible amount of another token.
//         This function makes use of the default solver
// @param _amount_in - The number of tokens that are supposed to be sold
// @param _amount_out_min - The minimum number of _token_out that have to be bought (fails if not reached)
// @param _token_in - The address of the token that would be sold
// @param _token_out - The address of the token that would be bought
// @param _to - The receiver address of the bought tokens
// @return received_amount - The token return amounts for each solver
@external
func swap_exact_tokens_for_tokens{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256, 
        _amount_out_min: Uint256, 
        _token_in: felt,
        _token_out: felt,
        _to: felt
    ) -> (amount_out: Uint256) {
    // Execute swap with solver 1 as the default
    let (received_amount: Uint256) = Hub.swap_with_solver(
        _token_in, _token_out, _amount_in, _amount_out_min, _to, 1
    );
    // Log swap
    swap_executed.emit(solver_used=0, amount_traded=_amount_in);

    return (received_amount,);
}

// @notice Swap an exact amount of a token for largest possible amount of another token.
//         This allows the user to specify the solver ID which will be used to find the best trading path
// @param _amount_in - The number of tokens that are supposed to be sold
// @param _amount_out_min - The minimum number of _token_out that have to be bought (fails if not reached)
// @param _token_in - The address of the token that would be sold
// @param _token_out - The address of the token that would be bought
// @param _to - The receiver address of the bought tokens
// @param _solver_id - The ID of the solver that will be used to find the best trading path
// @return received_amount - The token return amounts for each solver
@external
func swap_exact_tokens_for_tokens_with_solver{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _amount_in: Uint256,
        _min_amount_out: Uint256,
        _token_in: felt,
        _token_out: felt,
        _to: felt,
        _solver_id: felt,
    ) -> (received_amount: Uint256) {
    let (received_amount: Uint256) = Hub.swap_with_solver(
        _token_in, _token_out, _amount_in, _min_amount_out, _to, _solver_id
    );
    return (received_amount,);
}

// @notice Swap between two tokens by providing the exact routers and token address to be used. Aka the exat path to take.
// @param _routers - An array of routers to be used for the trades
// @param _path - An array of token pairs to trade
// @param _amounts - An array of token amounts (in %) to sell
// @param _amount_in - The initial token to sell
// @param _min_amount_out - The minimum amount of tokens to receive (will be the path.token_out of the last item in the path array)
// @return received_amount - The token return amounts for each solver
@external
func swap_with_path{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _amount_in: Uint256,
        _min_amount_out: Uint256,
    ) -> (received_amount: Uint256) {
    alloc_locals;

    ReentrancyGuard.start();

    // Get Caller Address
    let (caller_address) = get_caller_address();

    let (this_address) = get_contract_address();

    let (original_balance: Uint256) = IERC20.balanceOf(
        _path[_path_len - 1].token_out, this_address
    );

    // Delegate Call: Execute transactions
    let (trade_executor_hash) = Hub_trade_executor.read();

    // Execute Trades
    ITradeExecutor.library_call_multi_swap(
        trade_executor_hash,
        _routers_len,
        _routers,
        _path_len,
        _path,
        _amounts_len,
        _amounts,
        this_address
    );

    // Get new Balance of out_token
    let (new_amount: Uint256) = IERC20.balanceOf(_path[_path_len - 1].token_out, this_address);
    // ToDo: underlflow check
    let (received_amount: Uint256) = SafeUint256.sub_le(new_amount, original_balance);

    // Check that tokens received by solver at at least as much as the min_amount_out
    let (min_amount_received) = uint256_le(_min_amount_out, received_amount);
    assert min_amount_received = TRUE;

    // Transfer _token_out back to caller
    IERC20.transfer(_path[_path_len - 1].token_out, caller_address, received_amount);

    ReentrancyGuard.end();

    return (received_amount,);
}


//
// Admin functions
//

// @notice Set the address of the solver registry which will be used to validate solver IDs
// @param _new_registry - The address of the new solver registry 
@external
func set_solver_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _new_registry: felt
) -> () {
    Ownable.assert_only_owner();
    Hub.set_solver_registry(_new_registry);
    return ();
}

// @notice Set the new execution logic for trades
// @param _executor_hash - The class hash of the new transaction execution logic
@external
func set_executor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _executor_hash: felt
) {
    Ownable.assert_only_owner();
    Hub_trade_executor.write(_executor_hash);
    return ();
}

// @notice Set the new execution logic for trades
// @param _token - An array of tokens to retrieve from this contract
// @param _token_amount - An array of token amounts to retrieve
@external
func retrieve_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_len: felt, _token: felt*, _token_amount_len: felt, _token_amount: Uint256*
) -> () {
    Ownable.assert_only_owner();
    //ToDo implement token retieval logic
    return ();
}
