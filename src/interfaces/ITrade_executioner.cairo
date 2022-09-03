%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import Router, Path

@contract_interface
namespace ITrade_executioner:

    func multi_swap(
        _routers_len : felt,
        _routers : Router*,
        _path_len : felt,
        _path : Path*,
        _amounts_len : felt,
        _amounts : felt*,
        _receiver_address: felt,
        _amount_in: Uint256):
    end

    func simulate_multi_swap(
        _routers_len : felt,
        _routers : Router*,
        _path_len : felt,
        _path : Path*,
        _amounts_len : felt,
        _amounts : felt*,
        _amount_in: Uint256
    )->(amount_out: Uint256):
    end

end