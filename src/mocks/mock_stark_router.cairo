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

//
// ROUTER FUNCTIONS
//

func executeExactToMinRoute(input_token,input_token_amount,output_token,min_output_token_amount,recipient,route_array_len,route_array){
}


//
// FACTORY FUNCTIONS
//

func get_pair{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token1: felt, token2: felt)->(pair:felt){
    //We missuse the reserves amounts to check if the pair exists
    let (reserves_amount:Uint256) = get_reserves(token1,token2);
    if(reserves_amount.low == 0){
        return 0;
    } 
    //This address also acts as the pair contract
    let (address_this) = get_contract_address()
    return address_this;
}

//
// PAIR FUNCTIONS
//

func get_reserves{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(token1: felt, token2: felt)->(pair:felt){
    //We missuse the reserves amounts to check if the pair exists
    let (reserves_amount:Uint256) = get_reserves(token1,token2);
    if(reserves_amount.low == 0){
        return 0;
    } 
    //This address also acts as the pair contract
    let (address_this) = get_contract_address()
    return address_this;
}