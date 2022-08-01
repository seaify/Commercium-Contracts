%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ITrade_executioner:

    func multi_swap(
        _router_addresses_len : felt,
        _router_addresses : felt*,
        _router_types_len: felt,
        _router_types: felt*,
        _path_len : felt,
        _path : felt*,
        _amounts_len : felt,
        _amounts : felt*,
        _receiver_address: felt,
        _amount_in: Uint256):
    end

    func simulate_multi_swap(
        _router_addresses_len : felt,
        _router_addresses : felt*,
        _router_types_len: felt,
        _router_types: felt*,
        _path_len : felt,
        _path : felt*,
        _amounts_len : felt,
        _amounts : felt*,
        _amount_in: Uint256
    )->(amount_out: Uint256):
    end

end