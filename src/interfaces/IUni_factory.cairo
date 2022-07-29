%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IUni_factory:

    func get_pair(token0: felt, token1: felt) -> (pair: felt):
    end

end