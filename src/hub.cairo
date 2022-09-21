// SPDX-License-Identifier: MIT

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

from src.interfaces.ITrade_executor import ITrade_executor
from src.interfaces.IERC20 import IERC20

from src.openzeppelin.access.ownable import Ownable
from src.openzeppelin.security.reentrancy_guard import ReentrancyGuard
from src.openzeppelin.security.safemath import SafeUint256
from src.lib.utils import Router, Path
from src.lib.hub import Hub, Hub_trade_executor

//
// Views
//

@view
func solver_registry{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (solver_registry: felt) {
    let (solver_registry) = Hub.solver_registry();
    return (solver_registry,);
}

@view
func trade_executor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (trade_executor: felt) {
    let (trade_executor) = Hub.trade_executor();
    return (trade_executor,);
}

@view
func get_solver_amount{
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

@view
func get_solver_amount_exact_out{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(
            _amount_out: Uint256, 
            _token_in: felt, 
            _token_out: felt, 
            _solver_id: felt
        ) -> (amount_in: Uint256) {
    let (amount_in) = Hub.get_solver_amount_exact_out(_amount_out, _token_in, _token_out, _solver_id);

    return (amount_in=amount_in);
}

@view
func get_solver_amount_and_path{
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

@view
func get_amounts_out{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        amountIn: Uint256, 
        path_len: felt, 
        path: felt*
    ) -> (amounts_len: felt, amounts: Uint256*) {
    alloc_locals;

    // The user only dictates in_token and out_token
    with_attr error_message("HUB: Path should consist of exactly 2 tokens") {
        assert path_len = 2;
    }

    let (amount_out) = Hub.get_solver_amount(
        _amount_in=amountIn, _token_in=path[0], _token_out=path[1], _solver_id=1
    );

    let (return_amounts: Uint256*) = alloc();
    assert return_amounts[0] = amountIn;
    assert return_amounts[1] = amount_out;

    return (amounts_len=2, amounts=return_amounts);
}

//This function is mainly intended for off-chain queries
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

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_owner: felt) {
    Ownable.initializer(_owner);
    return ();
}

//
// Externals
//

@external
func swap_exact_tokens_for_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amountIn: Uint256, amountOutMin: Uint256, path_len: felt, path: felt*, to: felt, deadline: felt
) -> (amounts_len: felt, amounts: Uint256*) {
    alloc_locals;

    // Check that deadline hasn't past

    // Check that the proposed trade is only between two tokens
    assert path_len = 2;

    // Execute swap with solver 1 as the default
    let (received_amount: Uint256) = swap_with_solver(
        path[0], path[1], amountIn, amountOutMin, to, 1
    );

    // Transform output to conform with uniSwap Interface
    let (amounts: Uint256*) = alloc();
    assert amounts[0] = amountIn;
    assert amounts[1] = received_amount;

    return (2, amounts);
}

@external
func swap_tokens_for_exact_tokens{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        amountOut: Uint256, 
        amountInMax: Uint256, 
        path_len: felt, 
        path: felt*, 
        to: felt, 
        deadline: felt
    )->(amounts_len: felt, amounts: Uint256*) {
    alloc_locals;

    // Check that deadline hasn't past

    // Check that the proposed trade is only between two tokens
    assert path_len = 2;

    // Execute swap with solver 1 as the default
    let (amount_in: Uint256) = swap_with_solver_exact_out(
        path[0], path[1], amountOut, amountInMax, to, 1
    );

    // Transform output to conform with uniSwap Interface
    let (amounts: Uint256*) = alloc();
    assert amounts[0] = amount_in;
    assert amounts[1] = amountOut;

    return (2, amounts);
}

@external
func swap_with_solver{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token_in: felt,
        _token_out: felt,
        _amount_in: Uint256,
        _min_amount_out: Uint256,
        _to: felt,
        _solver_id: felt,
    ) -> (received_amount: Uint256) {
    let (received_amount: Uint256) = Hub.swap_with_solver(
        _token_in, _token_out, _amount_in, _min_amount_out, _to, _solver_id
    );
    return (received_amount,);
}

@external
func swap_with_solver_exact_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_in: felt,
    _token_out: felt,
    _amount_out: Uint256,
    _max_amount_in: Uint256,
    _to: felt,
    _solver_id: felt,
) -> (in_amount: Uint256) {
    let (in_amount: Uint256) = Hub.swap_with_solver_exact_out(
        _token_in, _token_out, _amount_out, _max_amount_in, _to, _solver_id
    );
    return (in_amount,);
}

@external
func swap_with_path{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
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

    ReentrancyGuard._start();

    // Get Caller Address
    let (caller_address) = get_caller_address();

    let (this_address) = get_contract_address();

    let (original_balance: Uint256) = IERC20.balanceOf(
        _path[_path_len - 1].token_out, this_address
    );

    // Delegate Call: Execute transactions
    let (trade_executor_hash) = Hub_trade_executor.read();

    // Execute Trades
    ITrade_executor.library_call_multi_swap(
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

    ReentrancyGuard._end();

    return (received_amount,);
}

//
// Admin functions
//

@external
func set_solver_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _new_registry: felt
) -> () {
    Ownable.assert_only_owner();
    Hub.set_solver_registry(_new_registry);
    return ();
}

@external
func set_executor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _executor_hash: felt
) {
    Ownable.assert_only_owner();
    Hub_trade_executor.write(_executor_hash);
    return ();
}

@external
func retrieve_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_len: felt, _token: felt*, _token_amount_len: felt, _token_amount: Uint256*
) -> () {
    Ownable.assert_only_owner();
    return ();
}
