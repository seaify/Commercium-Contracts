%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IAlphaFactory {
    func getPool(token0: felt, token1: felt) -> (pool: felt) {
    }
}

@contract_interface
namespace IJediFactory {
    func get_pair(token0: felt, token1: felt) -> (pair: felt) {
    }
}

@contract_interface
namespace ISithFactory {
    func pairFor(token0: felt, token1: felt, stable: felt) -> (pool: felt) {
    }
    func isPair(pair: felt) -> (is_pair: felt) {
    }
}

@contract_interface
namespace ITenKFactory {
    func getPair(token0: felt, token1: felt) -> (pair: felt) {
    }
}

@contract_interface
namespace IStarkFactory {
    func getPair(token0: felt, token1: felt) -> (pair: felt) {
    }
}
