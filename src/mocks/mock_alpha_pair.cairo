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

struct Pair {
    token_1: felt,
    token_2: felt,
}

struct Reserves {
    reserve_1: Uint256,
    reserve_2: Uint256,
}

@storage_var
func token0() -> (token0_address: felt) {
}


@storage_var
func reserves() -> (reserves: Reserves) {
}

@external
func set_reserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _reserve_1: Uint256, _reserve_2: Uint256
) {
    reserves.write(Reserves(_reserve_1, _reserve_2));
    return ();
}

@external
func set_token0{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token0_address
) {
    token0.write(token0_address);
    return();
}

@view
func getToken0{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}()->(token0: felt){
    let (token0_address) = token0.read();
    return(token0_address);
}

@view
func getReserves{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (reserve1: Uint256, reserve2: Uint256){
    let (token_reserves: Reserves) = reserves.read(Pair(_token_in, _token_out));
    return (token_reserves.reserve_1, token_reserves.reserve_2);
}