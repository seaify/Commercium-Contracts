%lang starknet

from protostar.asserts import assert_eq

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, sqrt, split_felt
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bitwise import bitwise_or
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_eq,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_signed_div_rem,
    uint256_unsigned_div_rem,
)

from src.lib.array import Array
from src.lib.utils import Utils
from src.lib.constants import MAX_FELT, JediSwap, SithSwap, TenK, AlphaRoad
from src.interfaces.i_router_aggregator import IRouterAggregator
from src.interfaces.i_solver import ISolver
from src.interfaces.i_spf_solver import ISpfSolver
from src.interfaces.i_solver_registry import ISolverRegistry
from src.interfaces.i_empiric_oracle import IEmpiricOracle
from src.interfaces.i_erc20 import IERC20
from src.interfaces.i_router import IJediRouter, ISithRouter, IAlphaRouter, ITenKRouter
from src.interfaces.i_hub import IHub
from src.interfaces.i_pool import IAlphaPool, ITenKPool, IJediPool, ISithPool
from src.lib.utils import Router, Path

@contract_interface
namespace IKeccak {
    func execute() -> (evm_address_low: felt,evm_address_high: felt){
    }
}


@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // Deploy Mock_Tokens
    local test_contract: felt;
    %{ ids.test_contract = deploy_contract("./src/keccak.cairo", []).contract_address %}
    %{ context.test_contract = ids.test_contract %}
    
    return ();
}

@external
func test_keccak{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local test_contract;
    %{ ids.test_contract = context.test_contract %}

    let (local evm_address_low, local evm_address_high) = IKeccak.execute(test_contract);

    let (high,low) = split_felt(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    local combined = evm_address_low + evm_address_high * 2 ** 128;

    %{  
        print("EVM address low: ", ids.evm_address_low)
        print("EVM address high: ", ids.evm_address_high)
        print("Split low: ", ids.low)
        print("Split high: ", ids.high)
        print("combined: ", ids.combined)
    %}
    assert 1 = 2;
    

    return ();
}
