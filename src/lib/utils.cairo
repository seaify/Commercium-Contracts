// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.registers import get_label_location
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

    func felt_fmul{range_check_ptr}(x: felt, y: felt, _base: felt) -> felt {
        tempvar mul_res = x * y;
        let (division, _) = unsigned_div_rem(mul_res, _base);
        return (division);
    }

    func felt_fdiv{range_check_ptr}(x: felt, y: felt, _base: felt) -> felt {
        tempvar mul_res = x * _base;
        let (division, _) = unsigned_div_rem(mul_res, y);
        return (division);
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

    // Copied from: https://github.com/NethermindEth/warp/blob/develop/warplib/maths/pow2.cairo
    func pow2(i) -> (res: felt) {
        let (data_address) = get_label_location(data);
        return ([data_address + i],);

        data:
        dw 0x1;
        dw 0x2;
        dw 0x4;
        dw 0x8;
        dw 0x10;
        dw 0x20;
        dw 0x40;
        dw 0x80;
        dw 0x100;
        dw 0x200;
        dw 0x400;
        dw 0x800;
        dw 0x1000;
        dw 0x2000;
        dw 0x4000;
        dw 0x8000;
        dw 0x10000;
        dw 0x20000;
        dw 0x40000;
        dw 0x80000;
        dw 0x100000;
        dw 0x200000;
        dw 0x400000;
        dw 0x800000;
        dw 0x1000000;
        dw 0x2000000;
        dw 0x4000000;
        dw 0x8000000;
        dw 0x10000000;
        dw 0x20000000;
        dw 0x40000000;
        dw 0x80000000;
        dw 0x100000000;
        dw 0x200000000;
        dw 0x400000000;
        dw 0x800000000;
        dw 0x1000000000;
        dw 0x2000000000;
        dw 0x4000000000;
        dw 0x8000000000;
        dw 0x10000000000;
        dw 0x20000000000;
        dw 0x40000000000;
        dw 0x80000000000;
        dw 0x100000000000;
        dw 0x200000000000;
        dw 0x400000000000;
        dw 0x800000000000;
        dw 0x1000000000000;
        dw 0x2000000000000;
        dw 0x4000000000000;
        dw 0x8000000000000;
        dw 0x10000000000000;
        dw 0x20000000000000;
        dw 0x40000000000000;
        dw 0x80000000000000;
        dw 0x100000000000000;
        dw 0x200000000000000;
        dw 0x400000000000000;
        dw 0x800000000000000;
        dw 0x1000000000000000;
        dw 0x2000000000000000;
        dw 0x4000000000000000;
        dw 0x8000000000000000;
        dw 0x10000000000000000;
        dw 0x20000000000000000;
        dw 0x40000000000000000;
        dw 0x80000000000000000;
        dw 0x100000000000000000;
        dw 0x200000000000000000;
        dw 0x400000000000000000;
        dw 0x800000000000000000;
        dw 0x1000000000000000000;
        dw 0x2000000000000000000;
        dw 0x4000000000000000000;
        dw 0x8000000000000000000;
        dw 0x10000000000000000000;
        dw 0x20000000000000000000;
        dw 0x40000000000000000000;
        dw 0x80000000000000000000;
        dw 0x100000000000000000000;
        dw 0x200000000000000000000;
        dw 0x400000000000000000000;
        dw 0x800000000000000000000;
        dw 0x1000000000000000000000;
        dw 0x2000000000000000000000;
        dw 0x4000000000000000000000;
        dw 0x8000000000000000000000;
        dw 0x10000000000000000000000;
        dw 0x20000000000000000000000;
        dw 0x40000000000000000000000;
        dw 0x80000000000000000000000;
        dw 0x100000000000000000000000;
        dw 0x200000000000000000000000;
        dw 0x400000000000000000000000;
        dw 0x800000000000000000000000;
        dw 0x1000000000000000000000000;
        dw 0x2000000000000000000000000;
        dw 0x4000000000000000000000000;
        dw 0x8000000000000000000000000;
        dw 0x10000000000000000000000000;
        dw 0x20000000000000000000000000;
        dw 0x40000000000000000000000000;
        dw 0x80000000000000000000000000;
        dw 0x100000000000000000000000000;
        dw 0x200000000000000000000000000;
        dw 0x400000000000000000000000000;
        dw 0x800000000000000000000000000;
        dw 0x1000000000000000000000000000;
        dw 0x2000000000000000000000000000;
        dw 0x4000000000000000000000000000;
        dw 0x8000000000000000000000000000;
        dw 0x10000000000000000000000000000;
        dw 0x20000000000000000000000000000;
        dw 0x40000000000000000000000000000;
        dw 0x80000000000000000000000000000;
        dw 0x100000000000000000000000000000;
        dw 0x200000000000000000000000000000;
        dw 0x400000000000000000000000000000;
        dw 0x800000000000000000000000000000;
        dw 0x1000000000000000000000000000000;
        dw 0x2000000000000000000000000000000;
        dw 0x4000000000000000000000000000000;
        dw 0x8000000000000000000000000000000;
        dw 0x10000000000000000000000000000000;
        dw 0x20000000000000000000000000000000;
        dw 0x40000000000000000000000000000000;
        dw 0x80000000000000000000000000000000;
        dw 0x100000000000000000000000000000000;
        dw 0x200000000000000000000000000000000;
        dw 0x400000000000000000000000000000000;
        dw 0x800000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000000000000000000000;
        dw 0x800000000000000000000000000000000000000000000000000000000000;
        dw 0x1000000000000000000000000000000000000000000000000000000000000;
        dw 0x2000000000000000000000000000000000000000000000000000000000000;
        dw 0x4000000000000000000000000000000000000000000000000000000000000;
        dw 0x8000000000000000000000000000000000000000000000000000000000000;
        dw 0x10000000000000000000000000000000000000000000000000000000000000;
        dw 0x20000000000000000000000000000000000000000000000000000000000000;
        dw 0x40000000000000000000000000000000000000000000000000000000000000;
        dw 0x80000000000000000000000000000000000000000000000000000000000000;
        dw 0x100000000000000000000000000000000000000000000000000000000000000;
        dw 0x200000000000000000000000000000000000000000000000000000000000000;
        dw 0x400000000000000000000000000000000000000000000000000000000000000;
    }
}
