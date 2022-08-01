%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IHub:

    func get_solver_result(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt, 
        _solver_id: felt)->(amount_out: Uint256):
    end

    func swap_with_solver(
        _token_in : felt, 
        _token_out : felt, 
        _amount_in : Uint256, 
        _min_amount_out : Uint256, 
        _solver_id : felt)->(received_amount: Uint256):
    end

    func set_solver_registry(_new_registry: felt):
    end

    func set_executor(_new_executor_hash: felt):
    end

end
