%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import Router, Path

@contract_interface
namespace ITrade_executor {
    func multi_swap(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _receiver_address: felt
    ){
    }

    func simulate_multi_swap(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _amount_in: Uint256,
    ) -> (amount_out: Uint256){
    }

    func simulate_multi_swap_exact_out(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _amount_out: Uint256,
    ) -> (amount_in: Uint256){
    }

    func multi_swap_exact_out(
        _routers_len: felt,
        _routers: Router*,
        _path_len: felt,
        _path: Path*,
        _amounts_len: felt,
        _amounts: felt*,
        _receiver_address: felt,
        _amount_out: Uint256
    ){
    }
}
