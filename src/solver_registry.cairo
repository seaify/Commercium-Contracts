%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from src.openzeppelin.access.ownable import Ownable

@storage_var
func solvers(index: felt)->(solver_address: felt):
end

@storage_var
func ids(solver_address: felt)->(id: felt):
end

@view
func get_solver{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_solver_id: felt) -> (solver_address: felt):
    let (solver_address) = solvers.read(_solver_id)
    return(solver_address)
end

@view
func get_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_solver_address: felt) -> (solver_id: felt):
    let (solver_id) = ids.read(_solver_address)
    return(solver_id)
end

@external
func set_solver{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _solver_id: felt, _solver_address: felt) -> ():
    #Ownable.assert_only_owner()
    ids.write(_solver_address,_solver_id)
    solvers.write(_solver_id,_solver_address)
    return()
end
