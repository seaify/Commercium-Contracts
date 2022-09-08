%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IAlpha_pool {

    func token0() -> (token0: felt){
    }

    func getReserves() -> (reserve_token_0: Uint256, reserve_token_1: Uint256){
    }
}

@contract_interface
namespace IJedi_pool {

    func token0() -> (token0: felt){
    }

    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt){
    }
}