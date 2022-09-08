%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import Router, Path

@contract_interface
namespace ISolver {

    func get_results(_amount_in: Uint256, _token_in: felt, _token_out: felt) -> (
        routers_len: felt,
        routers: Router*,
        path_len: felt,
        path: Path*,
        amounts_len: felt,
        amounts: felt*,
    ) {
    }

    func set_router_aggregator(_router_aggregator_address: felt) {
    }
}
