%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import Router
from src.lib.utils import Path

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

    func set_high_liq_tokens(_index: felt, _high_liq_tokens: felt) {
    }
}
