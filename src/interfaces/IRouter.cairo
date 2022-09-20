%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.lib.utils import SithSwapRoutes

@contract_interface
namespace IJedi_router {
    func swap_exact_tokens_for_tokens(
            amountIn: Uint256,
            amountOutMin: Uint256,
            path_len: felt,
            path: felt*,
            to: felt,
            deadline: felt,
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func swap_tokens_for_exact_tokens(
            amountOut: Uint256, 
            amountInMax: Uint256, 
            path_len: felt, 
            path: felt*, 
            to: felt, 
            deadline: felt
        ) -> (amounts_len: felt, amounts: Uint256*){
    }

    func get_pool_stats(token1: felt, token2: felt) -> (
        reserve1: Uint256, reserve2: Uint256, fee: felt
    ) {
    }

    func get_reserves(_token_in: felt, _token_out: felt) -> (reserve1: Uint256, reserve2: Uint256) {
    }

    func set_reserves(_token_in: felt, _token_out: felt, _reserve_1: Uint256, _reserve_2: Uint256) {
    }

    func get_amount_out(
            amountIn: Uint256, 
            reserveIn: Uint256, 
            reserveOut: Uint256
        ) -> (amountOut: Uint256) {
    }

    func get_amounts_out(
            amountIn: Uint256, 
            path_len: felt, 
            path: felt*
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func get_amount_in(
            amountOut: Uint256, 
            reserveIn: Uint256, 
            reserveOut: Uint256
        ) -> (amountIn: Uint256){
    }

    func get_amounts_in(
            amountOut: Uint256, 
            path_len: felt, 
            path: felt*
        ) -> (amounts_len: felt, amounts: Uint256*){
    }

    func factory() -> (address: felt) {
    }
}

@contract_interface
namespace IAlpha_router {
    
    func getFactory() -> (factory_address: felt){
    }

    func quote(
        amount_token_0: Uint256, 
        reserve_token_0: Uint256, 
        reserve_token_1: Uint256) 
        -> (amount_token_0: Uint256){
    }

    func removeLiquidityQuote(
        amount_lp: Uint256, 
        reserve_token_0: Uint256, 
        reserve_token_1: Uint256, 
        total_supply: Uint256) 
        -> (amount_token_0: Uint256, amount_token_1: Uint256){
    }

    func removeLiquidityQuoteByPool(
        amount_lp: Uint256, 
        pool_address: felt) 
        -> (token_0_address: felt, token_1_address: felt, amount_token_0: Uint256, amount_token_1: Uint256){
    }

    func addLiquidity(
        token_0_address: felt, 
        token_1_address: felt, 
        amount_0_desired: Uint256, 
        amount_1_desired: Uint256,
        amount_0_min: Uint256, 
        amount_1_min: Uint256) 
        -> (liquidity_minted: Uint256){
    }

    func removeLiquidity(
        token_0_address: felt, 
        token_1_address: felt, 
        amount_token_0_min: Uint256, 
        amount_token_1_min: Uint256,
        liquidity: Uint256) 
        -> (amount_token_0: Uint256, amount_token_1: Uint256){
    }

    func swapExactTokensForTokens(
        token_from_address: felt,
        token_to_address: felt,
        amount_token_from: Uint256,
        amount_token_to_min: Uint256) 
        -> (amount_out_received: Uint256){
    }

    func swapTokensForExactTokens(
        token_from_address: felt,
        token_to_address: felt,
        amount_token_to: Uint256,
        amount_token_from_max: Uint256) 
        -> (amount_out_received: Uint256){
    }

    func updateFactory(new_factory_address: felt) -> (success: felt){
    }

    func transferOwnership(new_owner: felt) -> (new_owner: felt){
    }
}

@contract_interface
namespace ISith_router {
    func swapExactTokensForTokensSimple(
            amount_in: Uint256,
            amount_out_min: Uint256,
            token_from: felt,
            token_to: felt,
            stable: felt,
            to: felt,
            deadline: felt
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func getAmountOut(
            amount_in: Uint256,
            token_in: felt,
            token_out: felt
        ) -> (amount_out: Uint256, stable: felt){
    }

    func getAmountsOut(
            amount_in: Uint256,
            routes_len: felt,
            routes: SithSwapRoutes*,
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func get_reserves(
            token_a: felt,
            token_b: felt,
            stable: felt
        ) -> (reserve1: Uint256, reserve2: Uint256){
    }
}

@contract_interface
namespace ITenK_router {

    func swapExactTokensForTokens(
            amountIn: Uint256,
            amountOutMin: Uint256,
            path_len: felt,
            path: felt*,
            to: felt,
            deadline: felt,
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }

    func getAmountsOut(
            amountIn: Uint256, 
            path_len: felt, 
            path: felt*
        ) -> (amounts_len: felt, amounts: Uint256*) {
    }
}
