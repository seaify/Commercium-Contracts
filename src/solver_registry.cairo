// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.openzeppelin.access.ownable import Ownable
from starkware.cairo.common.math import assert_le, assert_not_equal
from src.lib.constants import MAX_FELT

@event
func unofficial_solver_added(solver_address: felt, solver_id: felt) {
}

@event
func official_solver_added(solver_address: felt, solver_id: felt) {
}

//
// Storage
//

@storage_var
func solvers(index: felt) -> (solver_address: felt) {
}

@storage_var
func solvers_len() -> (len: felt) {
}

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_owner: felt) {
    // All unofficial solvers are saved at IDs 100+
    solvers_len.write(100);
    // Set contract owner
    Ownable.initializer(_owner);
    return ();
}

//
// View
//

@view
func get_solver{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(_solver_id: felt) -> (solver_address: felt) {
    let (solver_address) = solvers.read(_solver_id);
    return (solver_address,);
}

@view
func get_next_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    solver_id: felt
) {
    let (solver_id) = solvers_len.read();
    return (solver_id,);
}

//
// External
//

@external
func add_solver{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _solver_address: felt
) -> (id: felt) {
    let (len: felt) = solvers_len.read();
    // I mean...should never happen, but we are making sure
    assert_not_equal(len, MAX_FELT);
    assert_not_equal(len, 0);

    solvers.write(len, _solver_address);
    solvers_len.write(len + 1);

    unofficial_solver_added.emit(solver_address=_solver_address, solver_id=len);
    return (len,);
}

@external
func set_solver{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _solver_index: felt, _solver_address: felt
) {
    Ownable.assert_only_owner();
    // As 0 is the default value, we shouldn't use it as a solver_ID
    assert_not_equal(_solver_index, 0);
    // Official solvers are in the range of 0 and 100
    assert_le(_solver_index, 100);

    solvers.write(_solver_index, _solver_address);

    official_solver_added.emit(solver_address=_solver_address, solver_id=_solver_index);
    return ();
}
