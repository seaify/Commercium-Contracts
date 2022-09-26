%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IEmpiric_oracle {
    func get_value(key: felt, aggregation_mode: felt) -> (
        value: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
    ) {
    }

    // Just for tests
    func set_token_price(_key: felt, _aggregation_mode: felt, _price: felt, _decimals: felt) {
    }
}
