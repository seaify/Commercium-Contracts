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
from src.interfaces.i_pool import IAlphaPool

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
func pairs(pair: Pair) -> (pair_address: felt) {
}

@view
func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount_in: Uint256, _token_in: felt, _token_out: felt
) -> (amount_out: Uint256) {
    alloc_locals;

    let (pair_address) = pairs.read(Pair(_token_in,_token_out));
    let (reserve_1: Uint256, reserve_2: Uint256) = IAlphaPool.getReserves(pair_address);

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
    let (pair_address) = pairs.read(Pair(path[0],path[1]));
    let (reserve_1: Uint256, reserve_2: Uint256) = IAlphaPool.getReserves(pair_address);

    if (reserve_1.low == 0) {
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
func getFactory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt) {
    let (address) = get_contract_address();
    return (address,);
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
func set_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _token1: felt, 
        _token2: felt,
        _pair_address: felt
    ) {
    pairs.write(Pair(_token1,_token2),_pair_address);    
    pairs.write(Pair(_token2,_token1),_pair_address);
    return();
}

@external
func swapExactTokensForTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_from_address: felt,
        token_to_address: felt,
        amount_token_from: Uint256,
        amount_token_to_min: Uint256
    ) -> (amount_out_received: Uint256){
    alloc_locals;
    //Currently isn't reducing reserve amounts
    let (amount_out: Uint256) = get_amount_out(amount_token_from, token_from_address, token_to_address);
    let (caller_address) = get_caller_address();
    let (this_address) = get_contract_address();
    IERC20.transferFrom(token_from_address, caller_address, this_address, amount_token_from);
    IERC20.transfer(token_to_address, caller_address, amount_out);
    return (amount_out,);
}

@view
func quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount_token_0: Uint256, 
    reserve_token_0: Uint256, 
    reserve_token_1: Uint256) 
    -> (amount_token_0: Uint256){
    if (reserve_token_0.low == 0) {
        return (Uint256(0, 0),);
    } else {
        let (feed_amount: Uint256, _) = uint256_mul(amount_token_0, Uint256(997, 0));
        let (numerator, _) = uint256_mul(feed_amount, reserve_token_1);
        let (feed_reserve, _) = uint256_mul(reserve_token_0, Uint256(1000, 0));
        let (denominator, _) = uint256_add(feed_reserve, feed_amount);
        let (amount_out, _) = uint256_unsigned_div_rem(numerator, denominator);
        return (amount_out,);
    }
}

//
// FACTORY FUNCTIONS
//

@view
func getPool{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token1: felt, token2: felt)->(pair:felt){
    //We missuse the reserves amounts to check if the pair exists

    let (pair_address) = pairs.read(Pair(token1,token2));
    if(pair_address == 0){
        return (0,);
    } 
    
    let (token_reserve_1: Uint256,_) = IAlphaPool.getReserves(pair_address);
    
    if(token_reserve_1.low == 0){
        return (0,);
    } 
    return (pair_address,);
}


