%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ISpf_solver:
    func get_results(
        _amount_in: Uint256,
        _token_in: felt,
        _token_out: felt)
        -> (
        res1: felt,res2: felt,res3: felt,res4: felt,res5: felt,res6: felt):
    end

    func set_router_aggregator(_new_router_aggregator_address: felt):
    end
end