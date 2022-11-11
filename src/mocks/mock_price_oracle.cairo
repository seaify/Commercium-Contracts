%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin


struct Price {
    value: felt,
    decimals: felt,
}

@storage_var
func price(key: felt) -> (price: Price) {
}

@view
func get_spot_median{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _key: felt
) -> (value: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt) {
    let (current_price: Price) = price.read(_key);

    return (current_price.value, current_price.decimals, 0, 0);
}

@external
func set_token_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _key: felt, _price: felt, _decimals: felt
) {
    price.write(_key, Price(_price, _decimals));
    return ();
}
