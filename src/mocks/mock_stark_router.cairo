%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address
from starkware.cairo.common.cairo_builtins import HashBuiltin

struct Pair {
    token_1: felt,
    token_2: felt,
}

struct Reserves {
    reserve_1: Uint256,
    reserve_2: Uint256,
}

@storage_var
func reserves(pair: Pair) -> (reserves: Reserves) {
}

@storage_var
func factory_address() -> (address: felt) {
}

@external
func set_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_in: felt, _token_out: felt, _reserve_1: Uint256, _reserve_2: Uint256
) {
    reserves.write(Pair(_token_in, _token_out), Reserves(_reserve_1, _reserve_2));
    reserves.write(Pair(_token_out, _token_in), Reserves(_reserve_2, _reserve_1));
    return ();
}

@external
func set_factory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) {
    factory_address.write(address);
    return ();
}

//
// ROUTER FUNCTIONS
//

func executeExactToMinRoute(
    input_token,
    input_token_amount,
    output_token,
    min_output_token_amount,
    recipient,
    route_array_len,
    route_array,
) {
}

//
// FACTORY FUNCTIONS
//

func get_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token1: felt, token2: felt
) -> (pair: felt) {
    // We missuse the reserves amounts to check if the pair exists
    let (current_reserves: Reserves) = reserves.read(Pair(token1, token2));
    if (current_reserves.reserve_1.low == 0) {
        return 0;
    }
    // This address also acts as the pair contract
    let (address_this) = get_contract_address();
    return address_this;
}

//
// PAIR FUNCTIONS
//

func poolTokenBalance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_id: felt
) -> (balance: Uint256) {
    // We missuse the reserves amounts to check if the pair exists
    let (current_reserves: Reserves) = reserves.read(Pair(token1, token2));

    if (_token_id == 1) {
        return (current_reserves.reserve_1);
    } else {
        assert _token_id = 2;
        return (current_reserves.reserve_2);
    }
}
