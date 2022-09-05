# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (Uint256,uint256_mul,uint256_signed_div_rem,uint256_unsigned_div_rem)
from starkware.cairo.common.math import unsigned_div_rem

struct Router:
    member address: felt
    member type: felt
end

struct Liquidity:
    member in: Uint256
    member out: Uint256
end

struct Path:
    member token_in: felt
    member token_out: felt
end

namespace Utils:

    func not_equal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : felt, y : felt) -> (z : felt):
        if x != y:
	    return(1)
        else:
	    return(0)
        end     
    end

    func felt_fmul{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : felt, y : felt, _base : felt) -> (z : felt):
        tempvar mul_res = x * y
        let (division,_) = unsigned_div_rem(mul_res,_base)
        return(division)
    end  

    func felt_fdiv{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : felt, y : felt, _base : felt) -> (z : felt):
        tempvar mul_res = x * _base
        let (division,_) = unsigned_div_rem(mul_res,y)
        return(division)
    end  

    func fmul{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Uint256, y : Uint256, _base : Uint256) -> (z : Uint256):
        let (mul_res:Uint256,_) = uint256_mul(x,y)
        let (division:Uint256,_) = uint256_unsigned_div_rem(mul_res,_base)
        return(division)
    end  
  
    func fdiv{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : Uint256, y : Uint256, _base : Uint256) -> (z : Uint256):
        let (mul_res:Uint256,_) = uint256_mul(x,_base)
        let (division:Uint256,_) = uint256_signed_div_rem(mul_res,y)
        return(division)
    end

end
