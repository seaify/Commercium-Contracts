%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IUni_router:

    func swap_exact_tokens_for_tokens(amountIn: Uint256, amountOutMin: Uint256, path_len: felt, path: felt*, to: felt, deadline: felt) -> (amounts_len: felt, amounts: Uint256*):
    end

    func get_pool_stats(token1: felt,token2: felt) -> (reserve1:Uint256, reserve2: Uint256, fee: felt):
    end

    func get_reserves(_token_in: felt, _token_out: felt) -> (reserve1:Uint256, reserve2: Uint256):
    end

    func set_reserves(_token_in: felt, _token_out: felt, _reserve_1: Uint256, _reserve_2: Uint256):
    end

    func get_amount_out(amountIn: Uint256, reserveIn: Uint256, reserveOut: Uint256) -> (amountOut: Uint256):
    end

    func get_amounts_out(amountIn: Uint256, path_len: felt, path: felt*) -> (amounts_len: felt, amounts: Uint256*):
    end

end

