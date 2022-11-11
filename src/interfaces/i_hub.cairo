%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import Router
from src.lib.utils import Path

@contract_interface
namespace IHub {
    func solver_registry() -> (solver_registry: felt) {
    }

    func trade_executor() -> (trade_executor: felt) {
    }

    func get_amount_out_with_solver(
        _amount_in: Uint256, _token_in: felt, _token_out: felt, _solver_id: felt
    ) -> (amount_out: Uint256) {
    }

    func get_amount_and_path_with_solver(
        _amount_in: Uint256, _token_in: felt, _token_out: felt, _solver_id: felt
    ) -> (
        routers_len: felt,
        routers: Router*,
        path_len: felt,
        path: Path*,
        amounts_len: felt,
        amounts: felt*,
        amount_out: Uint256,
    ) {
    }

    func get_amount_out(_amount_in: Uint256, _token_in: felt, _token_out: felt) -> (
        amount: Uint256
    ) {
    }

    func get_multiple_solver_amounts(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt,
        _solver_ids_len: felt,
        _solver_ids: felt*,
    ) -> (amounts_out_len: felt, amounts_out: Uint256*) {
    }

    func swap_exact_tokens_for_tokens(
        _amount_in: Uint256, _amount_out_min: Uint256, _token_in: felt, _token_out: felt, _to: felt
    ) -> (amount_out: Uint256) {
    }

    func swap_exact_tokens_for_tokens_with_solver(
        _amount_in: Uint256,
        _min_amount_out: Uint256,
        _token_in: felt,
        _token_out: felt,
        _to: felt,
        _solver_id: felt,
    ) -> (received_amount: Uint256) {
    }

    func swap_with_path(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _amount_in: Uint256,
        _min_amount_out: Uint256,
    ) -> (received_amount: Uint256) {
    }

    func set_solver_registry(_new_registry: felt) -> () {
    }

    func set_executor(_executor_hash: felt) {
    }

    func retrieve_tokens(
        _token_len: felt, _token: felt*, _token_amount_len: felt, _token_amount: Uint256*
    ) -> () {
    }
}
