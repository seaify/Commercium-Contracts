%lang starknet

from protostar.asserts import (assert_eq)

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, sqrt
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bitwise import bitwise_or
from starkware.cairo.common.uint256 import (Uint256,uint256_le,uint256_eq,uint256_add,uint256_sub,uint256_mul,uint256_signed_div_rem,uint256_unsigned_div_rem)

from src.lib.array import Array
from src.lib.utils import Utils
from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.IERC20 import IERC20
from src.interfaces.IUni_router import IUni_router
from src.interfaces.ISpf_solver import ISpf_solver

const Vertices = 6
const Edges = 21
const LARGE_VALUE = 850705917302346000000000000000000000000000000 

const base = 1000000000000000000 # 1e18
const extra_base = 100000000000000000000 # We use this to artificialy increase the weight of each edge, so that we can subtract the last edges without causeing underflows

const Uni = 0

const shitcoin1 = 12344
const USDT = 12345
const USDC = 12346
const DAI = 12347
const ETH = 12348
const shitcoin2 = 12349

@external
func test_spf_solver{syscall_ptr : felt*, bitwise_ptr : BitwiseBuiltin*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local router_aggregator_address : felt
    # We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_aggregator_address = deploy_contract("./src/router_aggregator.cairo", []).contract_address %}
    
    # Set routers
    let (router_1_address) = create_router1()
    let (router_2_address) = create_router2()
    let (router_3_address) = create_router3()

    # Add newly created routers to router aggregator
    IRouter_aggregator.add_router(router_aggregator_address,router_1_address,Uni)
    IRouter_aggregator.add_router(router_aggregator_address,router_2_address,Uni)
    IRouter_aggregator.add_router(router_aggregator_address,router_3_address,Uni)  

    local spf_solver_address : felt
    %{ ids.spf_solver_address = deploy_contract("./src/solvers/spf_solver.cairo", []).contract_address %}

    ISpf_solver.set_router_aggregator(spf_solver_address,router_aggregator_address)
    #set_router_aggregator(router_aggregator_address)

    let (router_addresses_len : felt,
        router_addresses : felt*,
        router_types_len : felt,
        router_types : felt*,
        tokens_in_len : felt, 
        tokens_in : felt*,
        tokens_out_len : felt, 
        tokens_out : felt*,
        amounts_len : felt, 
        amounts : Uint256*, 
        amount_out: Uint256) = ISpf_solver.get_results(spf_solver_address,Uint256(100*base,0),shitcoin1, shitcoin2)
    
    #tempvar path0 = path[0]
    #tempvar path1 = path[1]
    #tempvar path2 = path[2]
    #tempvar path3 = path[3]
    
    #%{ print("path0: ",ids.path0) %}
    #%{ print("path1: ",ids.path1) %}
    #%{ print("path2: ",ids.path2) %}
    #%{ print("path3: ",ids.path3) %}

    return()
end

func create_router1{syscall_ptr : felt*, range_check_ptr}() -> (router_address:felt):
    alloc_locals

    local router_address : felt
    # We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_uni_router.cairo", []).contract_address %}
    
    #shitcoin1 = 10$
    #ETH = 1000$ ....sadge
    #DAI = 1$
    #USDT = 1$
    #USDC = 1$
    #shitcoin2 = 10$

    IUni_router.set_reserves(router_address,shitcoin1, ETH, Uint256(5000*base,0), Uint256(50*base,0))     #50,000
    IUni_router.set_reserves(router_address,shitcoin1, USDC, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,shitcoin1, DAI, Uint256(100*base,0), Uint256(1000*base,0))    #1000
    IUni_router.set_reserves(router_address,shitcoin1, USDT, Uint256(0,0), Uint256(0,0))        #0

    IUni_router.set_reserves(router_address,ETH, USDT, Uint256(100*base,0), Uint256(100000*base,0))       #100,000
    IUni_router.set_reserves(router_address,ETH, USDC, Uint256(10*base,0), Uint256(10000*base,0))         #10,000
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(10*base,0), Uint256(10000*base,0))          #10,000
    
    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    IUni_router.set_reserves(router_address,ETH, shitcoin2, Uint256(0*base,0), Uint256(0*base,0))     #0,000
    IUni_router.set_reserves(router_address,USDT, shitcoin2, Uint256(0,0), Uint256(0,0))        #0    
    IUni_router.set_reserves(router_address,USDC, shitcoin2, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,DAI, shitcoin2, Uint256(0,0), Uint256(0,0))         #0

    return(router_address)
end

func create_router2{syscall_ptr : felt*, range_check_ptr}() -> (router_address:felt):
    alloc_locals

    local router_address : felt
    # We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_uni_router.cairo", []).contract_address %}
    
    #shitcoin1 = 10$
    #ETH = 1000$ ....sadge
    #DAI = 1$
    #USDT = 1$
    #USDC = 1$
    #shitcoin2 = 10$

    IUni_router.set_reserves(router_address,shitcoin1, ETH, Uint256(0,0), Uint256(0,0))     #0
    IUni_router.set_reserves(router_address,shitcoin1, USDC, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,shitcoin1, DAI, Uint256(0,0), Uint256(0,0))     #0
    IUni_router.set_reserves(router_address,shitcoin1, USDT, Uint256(0,0), Uint256(0,0))        #0

    IUni_router.set_reserves(router_address,ETH, USDT, Uint256(0,0), Uint256(0,0))       #0
    IUni_router.set_reserves(router_address,ETH, USDC, Uint256(0,0), Uint256(0,0))         #0
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(1000*base,0), Uint256(1000000*base,0))          #1,000,000
    
    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    IUni_router.set_reserves(router_address,ETH, shitcoin2, Uint256(0,0), Uint256(0,0))         #0
    IUni_router.set_reserves(router_address,USDT, shitcoin2, Uint256(0*base,0), Uint256(0*base,0))   #0    
    IUni_router.set_reserves(router_address,USDC, shitcoin2, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,DAI, shitcoin2, Uint256(0,0), Uint256(0,0))         #0

    return(router_address)
end

func create_router3{syscall_ptr : felt*, range_check_ptr}() -> (router_address:felt):
    alloc_locals

    local router_address : felt
    # We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_uni_router.cairo", []).contract_address %}
    
    #shitcoin1 = 10$
    #ETH = 1000$ ....sadge
    #DAI = 1$
    #USDT = 1$
    #USDC = 1$
    #shitcoin2 = 10$

    IUni_router.set_reserves(router_address,shitcoin1, ETH, Uint256(0,0), Uint256(0,0))         #0
    IUni_router.set_reserves(router_address,shitcoin1, USDC, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,shitcoin1, DAI, Uint256(0,0), Uint256(0,0))         #0
    IUni_router.set_reserves(router_address,shitcoin1, USDT, Uint256(0,0), Uint256(0,0))        #0

    IUni_router.set_reserves(router_address,ETH, USDT, Uint256(100*base,0), Uint256(100000*base,0))       #100,000
    IUni_router.set_reserves(router_address,ETH, USDC, Uint256(10*base,0), Uint256(10000*base,0))         #10,000
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(100*base,0), Uint256(100000*base,0))          #100,000
    
    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    IUni_router.set_reserves(router_address,ETH, shitcoin2, Uint256(1*base,0), Uint256(100*base,0))     #1,000
    IUni_router.set_reserves(router_address,USDT, shitcoin2, Uint256(0,0), Uint256(0,0))        #0    
    IUni_router.set_reserves(router_address,USDC, shitcoin2, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,DAI, shitcoin2, Uint256(50000*base,0), Uint256(5000*base,0))         #50,000

    return(router_address)
end