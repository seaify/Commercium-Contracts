%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ISpfSolver {
    func get_results(_amount_in: Uint256, _token_in: felt, _token_out: felt) -> (
        routers_len: felt,
        routers: Router*,
        path_len: felt,
        path: Path*,
        amounts_len: felt,
        amounts: felt*,
    ) {
    }

    func set_router_aggregator(_new_router_aggregator_address: felt) {
    }

    func set_high_liq_tokens(_index: felt, _high_liq_tokens: felt) {
    }
}
