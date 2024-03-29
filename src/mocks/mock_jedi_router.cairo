%lang starknet

from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_unsigned_div_rem,
    uint256_mul,
)
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from src.interfaces.i_erc20 import IERC20
from src.interfaces.i_pool import IJediPool

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

@storage_var
func pairs(pair: Pair) -> (pair_address: felt) {
}

//
// ROUTER FUNCTION
//

@external
func set_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token1: felt, _token2: felt, _pair_address: felt
) {
    pairs.write(Pair(_token1, _token2), _pair_address);
    pairs.write(Pair(_token2, _token1), _pair_address);
    return ();
}

@view
func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (amount_out: Uint256) {
    alloc_locals;
    let (reserve_1: Uint256, reserve_2: Uint256) = get_reserves(_token_in, _token_out);

    if (reserve_1.low == 0) {
        return (Uint256(0, 0),);
    } else {
        let (feed_amount: Uint256, _) = uint256_mul(_amount_in, Uint256(997, 0));
        let (numerator, _) = uint256_mul(feed_amount, reserve_2);
        let (feed_reserve, _) = uint256_mul(reserve_1, Uint256(1000, 0));
        let (denominator, _) = uint256_add(feed_reserve, feed_amount);
        let (amount_out, _) = uint256_unsigned_div_rem(numerator, denominator);
        return (amount_out,);
    }
}

@view
func get_amounts_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, path_len: felt, path: felt*
) -> (amounts_len: felt, amounts: Uint256*) {
    alloc_locals;

    let (local amounts: Uint256*) = alloc();

    let (pair_address) = pairs.read(Pair(path[0], path[1]));

    let (reserve_1: Uint256, reserve_2: Uint256) = IJediPool.get_reserves(pair_address);

    if (reserve_1.low == 0) {
        local token1 = path[0];
        local token2 = path[1];
        with_attr error_message("Token Pair has no Liquidity. Token1 {token1} Token2 {token2}") {
            assert 1 = 0;
        }
        assert amounts[0] = Uint256(0, 0);
        assert amounts[1] = Uint256(0, 0);
        return (2, amounts);
    } else {
        let (feed_amount: Uint256, _) = uint256_mul(_amount_in, Uint256(997, 0));
        let (numerator, _) = uint256_mul(feed_amount, reserve_2);
        let (feed_reserve, _) = uint256_mul(reserve_1, Uint256(1000, 0));
        let (denominator, _) = uint256_add(feed_reserve, feed_amount);
        let (amount_out, _) = uint256_unsigned_div_rem(numerator, denominator);
        assert amounts[0] = _amount_in;
        assert amounts[1] = amount_out;
        return (2, amounts);
    }
}

@view
func get_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_in: felt, _token_out: felt
) -> (reserve1: Uint256, reserve2: Uint256) {
    let (pair_address) = pairs.read(Pair(_token_in, _token_out));

    let (reserve_1: Uint256, reserve_2: Uint256) = IJediPool.get_reserves(pair_address);

    return (reserve_1, reserve_2);
}

@view
func factory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt) {
    let (address_this) = get_contract_address();

    return (address_this,);
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

@external
func swap_exact_tokens_for_tokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256,
    _min_amount_out: Uint256,
    _path_len: felt,
    _path: felt*,
    _receiver_address: felt,
    _deadline: felt,
) -> (amounts_len: felt, amounts: Uint256*) {
    alloc_locals;
    let (amount_out: Uint256) = get_amount_out(_amount_in, _path[0], _path[1]);
    let (caller_address) = get_caller_address();
    let (this_address) = get_contract_address();
    IERC20.transferFrom(_path[0], caller_address, this_address, _amount_in);
    IERC20.transfer(_path[1], caller_address, amount_out);
    let (amounts: Uint256*) = alloc();
    assert amounts[0] = amount_out;
    return (1, amounts);
}

//
// FACTORY FUNCTIONS
//

@view
func get_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token1: felt, token2: felt
) -> (pair: felt) {
    // We missuse the reserves amounts to check if the pair exists

    let (pair_address) = pairs.read(Pair(token1, token2));
    if (pair_address == 0) {
        return (0,);
    }

    let (token_reserve_1: Uint256, _) = IJediPool.get_reserves(pair_address);

    if (token_reserve_1.low == 0) {
        return (0,);
    }
    return (pair_address,);
}
