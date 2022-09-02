%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import Router

@contract_interface
namespace ISpf_solver:
    func get_results(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt)-> (
        routers_len : felt,
        routers : Router*,
        tokens_in_len : felt, 
        tokens_in : felt*,
        tokens_out_len : felt, 
        tokens_out : felt*,
        amounts_len : felt, 
        amounts : Uint256*, 
        amount_out: Uint256):
    end

    func set_router_aggregator(_new_router_aggregator_address: felt):
    end
end