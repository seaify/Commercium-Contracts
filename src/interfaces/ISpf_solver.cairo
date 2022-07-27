%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ISpf_solver:
    func get_results(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt)-> (
        router_addresses_len : felt,
        router_addresses : felt*,
        router_types_len : felt,
        router_types : felt*,
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