// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_signed_div_rem,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.math import unsigned_div_rem

struct SithSwapRoutes {
    from_address: felt,
    to_address: felt,
    stable: felt,
}

struct Router {
    address: felt,
    type: felt,
}

struct Liquidity {
    in: Uint256,
    out: Uint256,
}

struct Path {
    token_in: felt,
    token_out: felt,
}

namespace Utils {
    func not_equal{}(x: felt, y: felt) -> (z: felt) {
        if (x != y) {
            return (1,);
        } else {
            return (0,);
        }
    }

    func felt_fmul{range_check_ptr}(x: felt, y: felt, _base: felt) -> (z: felt) {
        tempvar mul_res = x * y;
        let (division, _) = unsigned_div_rem(mul_res, _base);
        return (division,);
    }

    func felt_fdiv{range_check_ptr}(x: felt, y: felt, _base: felt) -> (z: felt) {
        tempvar mul_res = x * _base;
        let (division, _) = unsigned_div_rem(mul_res, y);
        return (division,);
    }

    func fmul{range_check_ptr}(x: Uint256, y: Uint256, _base: Uint256) -> (z: Uint256) {
        let (mul_res: Uint256, _) = uint256_mul(x, y);
        let (division: Uint256, _) = uint256_unsigned_div_rem(mul_res, _base);
        return (division,);
    }

    func fdiv{range_check_ptr}(x: Uint256, y: Uint256, _base: Uint256) -> (z: Uint256) {
        let (mul_res: Uint256, _) = uint256_mul(x, _base);
        let (division: Uint256, _) = uint256_signed_div_rem(mul_res, y);
        return (division,);
    }
}
