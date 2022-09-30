%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IAlpha_factory {
    func getPool(token0: felt, token1: felt) -> (pool: felt) {
    }
}

@contract_interface
namespace IJedi_factory {
    func get_pair(token0: felt, token1: felt) -> (pair: felt) {
    }
}
