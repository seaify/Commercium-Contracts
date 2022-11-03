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
from src.lib.utils import SithSwapRoutes

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

@view
func getAmountOut{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (amount_out: Uint256, stable: felt) {
    alloc_locals;
    let (reserve_1: Uint256, reserve_2: Uint256) = get_reserves(_token_in, _token_out);

    if (reserve_1.low == 0) {
        return (Uint256(0, 0), 0);
    } else {
        let (feed_amount: Uint256, _) = uint256_mul(_amount_in, Uint256(997, 0));
        let (numerator, _) = uint256_mul(feed_amount, reserve_2);
        let (feed_reserve, _) = uint256_mul(reserve_1, Uint256(1000, 0));
        let (denominator, _) = uint256_add(feed_reserve, feed_amount);
        let (amount_out, _) = uint256_unsigned_div_rem(numerator, denominator);
        return (amount_out, 0);
    }
}

@view
func getAmountsOut{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_in: Uint256, routes_len: felt, routes: SithSwapRoutes*
) -> (amounts_len: felt, amounts: Uint256*) {
    alloc_locals;

    let (local amounts: Uint256*) = alloc();
    let (reserve_1: Uint256, reserve_2: Uint256) = get_reserves(
        routes[0].from_address, routes[0].to_address
    );

    if (reserve_1.low == 0) {
        assert amounts[0] = Uint256(0, 0);
        assert amounts[1] = Uint256(0, 0);
        return (2, amounts);
    } else {
        let (feed_amount: Uint256, _) = uint256_mul(amount_in, Uint256(997, 0));
        let (numerator, _) = uint256_mul(feed_amount, reserve_2);
        let (feed_reserve, _) = uint256_mul(reserve_1, Uint256(1000, 0));
        let (denominator, _) = uint256_add(feed_reserve, feed_amount);
        let (amount_out, _) = uint256_unsigned_div_rem(numerator, denominator);
        assert amounts[0] = amount_in;
        assert amounts[1] = amount_out;
        return (2, amounts);
    }
}

@view
func get_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _token_in: felt, _token_out: felt
) -> (reserve1: Uint256, reserve2: Uint256) {
    let (token_reserves: Reserves) = reserves.read(Pair(_token_in, _token_out));

    return (token_reserves.reserve_1, token_reserves.reserve_2);
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
func swapExactTokensForTokensSimple{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    amount_in: Uint256,
    amount_out_min: Uint256,
    token_from: felt,
    token_to: felt,
    stable: felt,
    to: felt,
    deadline: felt,
) -> (amounts_len: felt, amounts: Uint256*) {
    alloc_locals;
    let (amount_out: Uint256, _) = getAmountOut(amount_in, token_from, token_to);
    let (caller_address) = get_caller_address();
    let (this_address) = get_contract_address();
    IERC20.transferFrom(token_from, caller_address, this_address, amount_in);
    IERC20.transfer(token_to, to, amount_out);
    let (amounts: Uint256*) = alloc();
    assert amounts[0] = amount_out;
    return (1, amounts);
}

//
// FACTORY FUNCTIONS
//

@view
func pairFor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token0: felt, token1: felt, stable: felt
) -> (pair: felt) {
    // This address also acts as the pair contract
    let (address_this) = get_contract_address();
    return (address_this,);
}

@view
func isPair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_address: felt
) -> (is_pair: felt) {
    // Not sure how else to do this atm
    // We just assume that every pair exists
    return (1,);
}
