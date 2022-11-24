// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.3.2 (upgrades/presets/Proxy.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import library_call
from openzeppelin.upgrades.library import Proxy
from openzeppelin.access.ownable.library import Ownable

// /////////////////////////////////////////////////////////////
//                                                            //
//   Proxy Contract which implements the Router Aggregator    //
//                                                            //
// /////////////////////////////////////////////////////////////

// //////////////////////
//       Views        //
// //////////////////////

// @notice get the implemented contract hash
// @return implementation - The implementation contract hash
@view
func get_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    implementation: felt
) {
    let (implementation) = Proxy.get_implementation_hash();
    return (implementation,);
}

// @notice get the address of the proxy owner
// @return admin - The address of the contract owner/admin
@view
func get_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (admin: felt) {
    let (admin) = Proxy.get_admin();
    return (admin,);
}

// //////////////////////
//     Constructor    //
// //////////////////////

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _implementation_hash: felt, _admin: felt, _owner: felt
) {
    // Setting the proxy admin
    Proxy.initializer(_admin);
    Proxy._set_implementation_hash(_implementation_hash);
    // Setting the router aggregator owner
    Ownable.initializer(_owner);
    return ();
}

// ////////////////
//     Admin    //
// ////////////////

// @notice set the implementation contract class hash for this proxy
// @param _new_implementation - The class hash of the implementation
@external
func set_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(_new_implementation);
    return ();
}

// @notice Set the contract owner/admin
// @param _new_admin - The address of the owner/admin
@external
func _set_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_new_admin: felt) {
    Proxy.assert_only_admin();
    Proxy._set_admin(_new_admin);
    return ();
}

// ////////////////////////////
//     Fallback function    //
// ////////////////////////////

@external
@raw_input
@raw_output
func __default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) -> (retdata_size: felt, retdata: felt*) {
    let (class_hash) = Proxy.get_implementation_hash();

    let (retdata_size: felt, retdata: felt*) = library_call(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );

    return (retdata_size=retdata_size, retdata=retdata);
}
