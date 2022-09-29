%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IMockJediRouter {
    func get_amount_out(_amount_in: Uint256, _token_in: felt, _token_out: felt) -> (
        amount_out: Uint256
    ) {
    }

    func ashud_dasd(
        _amount_in: Uint256, _token_in_len: felt, _token_in: felt*, _token_out: felt
    ) -> (amount_out: Uint256) {
    }

    func get_amounts_out(_amount_in: Uint256, path_len: felt, path: felt*) -> (
        amounts_len: felt, amounts: Uint256*
    ) {
    }

    func get_reserves(_token_in: felt, _token_out: felt) -> (reserve1: Uint256, reserve2: Uint256) {
    }

    func factory() -> (address: felt) {
    }

    func set_reserves(_token_in: felt, _token_out: felt, _reserve_1: Uint256, _reserve_2: Uint256) {
    }

    func set_factory(address: felt) {
    }

    func swap_exact_tokens_for_tokens(
        _amount_in: Uint256,
        _min_amount_out: Uint256,
        _path_len: felt,
        _path: felt*,
        _receiver_address: felt,
        _deadline: felt,
    ) -> (amounts_len: felt, amounts: Uint256*) {
    }
}
