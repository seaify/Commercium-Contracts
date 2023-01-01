// SPDX-License-Identifier: MIT
// @author FreshPizza

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from src.interfaces.i_solver import ISolver
from src.interfaces.i_solver_registry import ISolverRegistry
from src.interfaces.i_trade_executor import ITradeExecutor
from src.lib.utils import Router, Path

from openzeppelin.security.reentrancyguard.library import ReentrancyGuard
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.token.erc20.IERC20 import IERC20

const multi_call_selector = 558079996720636069421427664524843719962060853116440040296815770714276714984;
const simulate_multi_swap_selector = 1310124106700095074905752334807922719347974895149925748802193060450827293357;

// //////////////////////////
//        Storage         //
// //////////////////////////

@storage_var
func Hub_trade_executor() -> (trade_executor_address: felt) {
}

@storage_var
func Hub_solver_registry() -> (registry_address: felt) {
}

namespace Hub {
    // ////////////////////////
    //  Don't Effect State  //
    // ////////////////////////

    // @notice Fetch the address of the solver registry contract
    // @return _solver_registry - Address of the solver registry
    func solver_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        solver_registry: felt
    ) {
        let (solver_registry) = Hub_solver_registry.read();
        return (solver_registry,);
    }

    // @notice Fetch the contract hash of the trade executor logic
    // @return trade_executor - contract hash of the trade_executor
    func trade_executor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        trade_executor: felt
    ) {
        let (trade_executor) = Hub_trade_executor.read();
        return (trade_executor,);
    }

    // @notice Fetch the return amount of a specified solver
    // @param _amount_in - Amount of tokens to sell
    // @param _token_in - Address of the token to be sold
    // @param _token_out - Address of the token to be bought
    // @param _solver_id - ID of the solver to be used
    // @return amount_out - The amount of _token_out that where bought
    func get_solver_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _amount_in: Uint256, _token_in: felt, _token_out: felt, _solver_id: felt
    ) -> (amount_out: Uint256) {
        alloc_locals;

        let (solver_registry) = Hub.solver_registry();
        let (local solver_address) = ISolverRegistry.get_solver(solver_registry, _solver_id);
        with_attr error_message("solver ID invalid") {
            assert_not_equal(solver_address, FALSE);
        }

        // Get trading path from the selected solver
        let (
            routers_len: felt,
            routers: Router*,
            path_len: felt,
            path: Path*,
            amounts_len: felt,
            amounts: felt*,
        ) = ISolver.get_results(solver_address, _amount_in, _token_in, _token_out);

        let (trade_executor_hash) = Hub_trade_executor.read();

        // Execute Trades
        let (amount_out: Uint256) = ITradeExecutor.library_call_simulate_multi_swap(
            trade_executor_hash,
            routers_len,
            routers,
            path_len,
            path,
            amounts_len,
            amounts,
            _amount_in,
        );

        return (amount_out,);
    }

    // @notice This method allows to query multiple solver results at once
    // @param _amount_in - Amount of _token_in to be sold
    // @param _token_in - Address of the token to be sold
    // @param _token_out - Address of the token to be bought
    // @param _solver_ids - An array of the solver IDs to get the out amounts from 
    // @param _amounts_out - An empty array of result amounts that will be filled by this method. 
    func get_multiple_solver_amounts{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _solver_ids_len: felt,
        _solver_ids: felt*,
        _amounts_out: Uint256*,
    ) {
        if (_solver_ids_len == 0) {
            return ();
        }

        let (amounts_out: Uint256) = Hub.get_solver_amount(
            _amount_in, _token_in, _token_out, _solver_ids[0]
        );

        assert _amounts_out[0] = amounts_out;

        get_multiple_solver_amounts(
            _amount_in,
            _token_in,
            _token_out,
            _solver_ids_len - 1,
            _solver_ids + 1,
            _amounts_out + 2,
        );

        return ();
    }

    // @notice This method allows to query multiple solver results at once
    // @param _amount_in - Amount of _token_in to be sold
    // @param _token_in - Address of the token to be sold
    // @param _token_out - Address of the token to be bought
    // @param _solver_ids - An array of the solver IDs to get the out amounts from 
    // @param _amounts_out - An empty array of result amounts that will be filled by this method. 
    func get_solver_amount_and_path{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(_amount_in: Uint256, _token_in: felt, _token_out: felt, _solver_id: felt) -> (
        routers_len: felt,
        routers: Router*,
        path_len: felt,
        path: Path*,
        amounts_len: felt,
        amounts: felt*,
        amount_out: Uint256,
    ) {
        alloc_locals;

        let (solver_registry) = Hub.solver_registry();
        let (local solver_address) = ISolverRegistry.get_solver(solver_registry, _solver_id);
        with_attr error_message("solver ID invalid") {
            assert_not_equal(solver_address, FALSE);
        }

        // Get trading path from the selected solver
        let (
            routers_len: felt,
            routers: Router*,
            path_len: felt,
            path: Path*,
            amounts_len: felt,
            amounts: felt*,
        ) = ISolver.get_results(solver_address, _amount_in, _token_in, _token_out);

        let (trade_executor_hash) = Hub_trade_executor.read();

        // Execute Trades
        let (amount_out: Uint256) = ITradeExecutor.library_call_simulate_multi_swap(
            trade_executor_hash,
            routers_len,
            routers,
            path_len,
            path,
            amounts_len,
            amounts,
            _amount_in,
        );

        return (routers_len, routers, path_len, path, amounts_len, amounts, amount_out);
    }

    // //////////////////
    //  Effect State  //
    // //////////////////

    // @notice Perform a swap with a specified solver
    // @param _token_in - Address of the token to be sold
    // @param _token_out - Address of the token to be bought
    // @param _amount_in - Amount of _token_in to be sold
    // @param _min_amount_out - Minimum amount of _token_out ot be sold
    // @param _to - The receiver of the bought _token_in tokens
    // @param _solver_id - The id of the solver to be used to perform the trade
    func swap_with_solver{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token_in: felt,
        _token_out: felt,
        _amount_in: Uint256,
        _min_amount_out: Uint256,
        _to: felt,
        _solver_id: felt,
    ) -> (received_amount: Uint256) {
        alloc_locals;

        ReentrancyGuard.start();

        // Get Solver address that will be used
        let (solver_registry) = Hub.solver_registry();
        let (solver_address) = ISolverRegistry.get_solver(solver_registry, _solver_id);
        with_attr error_message("solver ID invalid") {
            assert_not_equal(solver_address, FALSE);
        }

        // Get Caller Address
        let (caller_address) = get_caller_address();
        // Get Hub Address
        let (this_address) = get_contract_address();
        // Send tokens_in to the hub
        IERC20.transferFrom(_token_in, caller_address, this_address, _amount_in);

        // Check current token balance
        // (Used to determine received amount)
        let (original_balance: Uint256) = IERC20.balanceOf(_token_out, this_address);

        // Get trading path from the selected solver
        let (
            routers_len: felt,
            routers: Router*,
            path_len: felt,
            path: Path*,
            amounts_len: felt,
            amounts: felt*,
        ) = ISolver.get_results(solver_address, _amount_in, _token_in, _token_out);

        // Get trade executor class hash
        let (trade_executor_hash) = Hub_trade_executor.read();

        // Delegate Call: Execute transactions
        ITradeExecutor.library_call_multi_swap(
            trade_executor_hash,
            routers_len,
            routers,
            path_len,
            path,
            amounts_len,
            amounts,
            this_address,
        );

        // Check received Amount
        // We do not naively transfer out the entire balance of that token, as the hub might be holding more
        // tokens that it received as rewards or that where mistakenly sent here
        let (new_amount: Uint256) = IERC20.balanceOf(_token_out, this_address);
        let (received_amount: Uint256) = SafeUint256.sub_le(new_amount, original_balance);

        // Check that tokens received by solver at at least as much as the min_amount_out
        let (is_min_amount_received) = uint256_le(_min_amount_out, received_amount);
        with_attr error_message("Minimum amount not received") {
            assert is_min_amount_received = TRUE;
        }

        // Transfer _token_out back to caller
        IERC20.transfer(_token_out, _to, received_amount);

        ReentrancyGuard.end();

        return (received_amount,);
    }

    // @notice Swap between two tokens by providing the exact routers and token address to be used. Aka the exat path to take.
    // @param _routers - An array of routers to be used for the trades
    // @param _path - An array of token pairs to trade
    // @param _amounts - An array of token amounts (in %) to sell
    // @param _amount_in - The initial token to sell
    // @param _min_amount_out - The minimum amount of tokens to receive (will be the path.token_out of the last item in the path array)
    // @return received_amount - The token return amounts for each solver
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

        // Get Caller Address
        let (caller_address) = get_caller_address();

        let (this_address) = get_contract_address();

        let (original_balance: Uint256) = IERC20.balanceOf(
            _path[_path_len - 1].token_out, this_address
        );

        // Delegate Call: Execute transactions
        let (trade_executor_hash) = Hub_trade_executor.read();

        //Transfer assets from caller to hub (Storage write cost should be refunded, as the balance is return back to 0 after trade)
        IERC20.transferFrom(_path[0].token_in, caller_address, this_address, _amount_in);

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

        return (received_amount,);
    }

    // @notice Store the address of the solver registry
    // @param _new_registry - Address of the solver registry contract
    func set_solver_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _new_registry: felt
    ) -> () {
        Hub_solver_registry.write(_new_registry);
        return ();
    }
}
