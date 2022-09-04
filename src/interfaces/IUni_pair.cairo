%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IUni_pair:

    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt):
    end

    func token1() -> (address: felt):
    end

end