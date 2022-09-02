%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import Router

@contract_interface
namespace IHub:

    func solver_registry() -> (solver_registry: felt):
    end

    func get_solver_result(
            _amount_in: Uint256, 
            _token_in: felt, 
            _token_out: felt, 
            _solver_id: felt
        )->(amount_out: Uint256):
    end

    func get_amounts_out(
            amountIn: Uint256, 
            path_len: felt, 
            path: felt*
        ) -> (amounts_len: felt, amounts: Uint256*):
    end

    func swap_with_solver(
        _token_in : felt, 
        _token_out : felt, 
        _amount_in : Uint256, 
        _min_amount_out : Uint256, 
        _to : felt,
        _solver_id : felt)->(received_amount: Uint256):
    end    

    func swap_with_path(
            routers_len : felt,
            routers : Router*,
            _path_len: felt,
            _path: felt*,
            _amounts_len: felt,
            _amounts: felt*,
            _amount_in : Uint256, 
            _min_amount_out : Uint256
        ):
    end

    func swap_exact_tokens_for_tokens(
            amountIn: Uint256, 
            amountOutMin: Uint256, 
            path_len: felt, 
            path: felt*, 
            to: felt, 
            deadline: felt
        ) -> (amounts_len: felt, amounts: Uint256*):
    end

    func set_solver_registry(_new_registry: felt):
    end

    func set_executor(_new_executor_hash: felt):
    end

end
