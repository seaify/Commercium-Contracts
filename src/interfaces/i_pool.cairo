%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IAlphaPool {
    func getToken0() -> (token0: felt) {
    }

    func getReserves() -> (reserve_token_0: Uint256, reserve_token_1: Uint256) {
    }

    func set_token0(token0_address) {
    }

    func set_reserves(_reserve_1: Uint256, _reserve_2: Uint256) {
    }
}

@contract_interface
namespace IJediPool {
    func token0() -> (token0: felt) {
    }

    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt) {
    }
}

@contract_interface
namespace ISithPool {
    func token0() -> (token0: felt) {
    }

    func getReserves() -> (reserve_token_0: Uint256, reserve_token_1: Uint256) {
    }
}

@contract_interface
namespace ITenKPool {
    func token0() -> (token0: felt) {
    }

    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt) {
    }
}

@contract_interface
namespace IStarkPool {
    func TokenA() -> (token0: felt) {
    }

    func poolTokenBalance(token_id: felt) -> (balance: Uint256) {
    }

    func getInputPrice(_amount_in: Uint256, reserve2: Uint256, reserve1: Uint256) -> (
        price: Uint256
    ) {
    }
}
