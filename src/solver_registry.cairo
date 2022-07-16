%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.openzeppelin.access.ownable import Ownable
from starkware.cairo.common.math import assert_le

#
# Storage
#

@storage_var
func solvers(index: felt)->(solver_address: felt):
end

@storage_var
func solvers_len()->(len: felt):
end

#
# Constructor
#

@constructor
func constructor{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    #All unofficial solvers are saved at IDs 100+
    solvers_len.write(100)
    return()
end

#
# View
#

@view
func get_solver{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_solver_id: felt) -> (solver_address: felt):
    let (solver_address) = solvers.read(_solver_id)
    return(solver_address)
end

#
# External
#

@external
func add_solver{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(_solver_address: felt):
    let (len: felt) = solvers_len.read()
    solvers.write(len,_solver_address)
    solvers_len.write(len+1)
    #EMIT EVENT: ID, Address
    return()
end

func set_solver{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}(_solver_index: felt, _solver_address: felt):
    #Ownable.assert_only_owner()
    assert_le(_solver_index,100)
    solvers.write(_solver_index,_solver_address)
    #EMIT EVENT: ID, Address
    return()
end
