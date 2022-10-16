%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IAlphaPool {

    func token0() -> (token0: felt){
    }

    func getReserves() -> (reserve_token_0: Uint256, reserve_token_1: Uint256){
    }
}

@contract_interface
namespace IJediPool {

    func token0() -> (token0: felt){
    }

    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt){
    }
}


@contract_interface
namespace ISithPool {

    func token0() -> (token0: felt){
    }

    func getReserves() -> (reserve_token_0: Uint256, reserve_token_1: Uint256){
    }
}

@contract_interface
namespace ITenKPool {

    func token0() -> (token0: felt){
    }

    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt){
    }
}