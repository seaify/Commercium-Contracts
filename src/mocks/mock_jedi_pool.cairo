%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@view
func get_token0{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}()->(address: felt){
}

@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}()->(reserve0: felt, reserve1: felt){
} 