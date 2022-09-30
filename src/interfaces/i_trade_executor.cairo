%lang starknet

from src.lib.utils import Router

from src.lib.utils import Path

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ITradeExecutor {
    func simulate_multi_swap(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _amount_in: Uint256,
    ) -> (amount_out: Uint256) {
    }

    func simulate_multi_swap_exact_out(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _amount_out: Uint256,
    ) -> (amount_in: Uint256) {
    }

    func multi_swap(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _receiver_address: felt,
    ) {
    }

    func multi_swap_exact_out(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _receiver_address: felt,
        _amount_out: Uint256,
    ) {
    }
}
