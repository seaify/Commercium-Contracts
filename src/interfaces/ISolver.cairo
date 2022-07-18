%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.hub import Swap

@contract_interface
namespace ISolver:

    ####
    #Determines trading path and executes transactions on-chain 
    ####
    #Parameters:
    #_amount_in      | number of _token_in that caller wants to sell
    #_token_in       | address of the token that will be sold
    #_token_out      | address of the token that will be bought
    #Return Values:
    #return_amount   | the total amount of _token_out that was bought by the solver
    func execute_solver(
        _amount_in: Uint256, 
        _token_in: felt, 
        _token_out: felt,
        _receiver: felt
    ) -> (return_amount: Uint256):
    end

    ####
    #Returns trading path and expected return amount
    ####
    #Parameters:
    #_amount_in      | number of _token_in that caller wants to sell
    #_token_in       | address of the token that will be sold
    #_token_out      | address of the token that will be bought
    #_min_amount_out | minimum amount of _token_out that will be received by the caller
    #Return Values:
    #routers_len + routers             | array of AMM routers that swaps are performed on 
    #token_in_len + token_in           | array of token addresses that will be sold
    #token_out_len + token_out	       | array of token addresses that will be received
    #token_amounts_len + token_amounts | array of token_in amounts that will be sold for token_out 
    #min_amount_out		       | minimum amount of _token_out that would be received if logic would have been computed in that moment 
    func get_results(
        _amount_in: Uint256,
        _token_in: felt, 
        _token_out: felt
    ) -> (
        routers_len : felt,
        routers : felt*,
        tokens_in_len : felt, 
        tokens_in : felt*,
        tokens_out_len : felt, 
        tokens_out : felt*,
        amounts_len : felt, 
        amounts : felt*, 
        return_amount: Uint256
    ):
    end

    func set_router_aggregator(_router_aggregator_address: felt):
    end
end
