%lang starknet

from starkware.cairo.common.uint256 import (Uint256, uint256_add, uint256_mul, uint256_unsigned_div_rem)

from protostar.asserts import (assert_eq)

from src.interfaces.ISpf_solver import ISpf_solver
from src.interfaces.IUni_router import IUni_router
from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.lib.utils import Utils

const Uni = 0

const shitcoin1 = 12344
const USDT = 12345
const USDC = 12346
const DAI = 12347
const ETH = 12348
const shitcoin2 = 12349

const base = 1000

@external
func test_router_aggregator{syscall_ptr : felt*, range_check_ptr}():
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

    #let (final_amount_out1: Uint256, router_address: felt, router_type: felt) = IRouter_aggregator.get_single_best_pool( router_aggregator_address, Uint256(10*base,0), shitcoin1, ETH)
    #%{ print("final_amount_out1: ",ids.final_amount_out1.low) %}
    #let (final_amount_out2: Uint256, router_address: felt, router_type: felt) = IRouter_aggregator.get_single_best_pool( router_aggregator_address, Uint256(10*base,0), shitcoin1, DAI)
    #%{ print("final_amount_out2: ",ids.final_amount_out2.low) %}
    #let (final_amount_out3: Uint256, router_address: felt, router_type: felt) = IRouter_aggregator.get_single_best_pool( router_aggregator_address, Uint256(10*base,0), shitcoin1, USDT)
    #%{ print("final_amount_out3: ",ids.final_amount_out3.low) %}
    #let (final_amount_out4: Uint256, router_address: felt, router_type: felt) = IRouter_aggregator.get_single_best_pool( router_aggregator_address, Uint256(10*base,0), shitcoin1, USDC)
    #%{ print("final_amount_out4: ",ids.final_amount_out4.low) %}
    #assert_eq(router_address,router_3_address)

    local spf_solver_address : felt
    # We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.spf_solver_address = deploy_contract("./src/solvers/spf_solver.cairo", []).contract_address %}

    ISpf_solver.set_router_aggregator(spf_solver_address,router_aggregator_address)

    let (start: felt,stop: felt) = ISpf_solver.get_results(spf_solver_address,Uint256(10*base,0),shitcoin1, shitcoin2)
    %{ print("start: ",ids.start) %}
    %{ print("stop: ",ids.stop) %}
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

    IUni_router.set_reserves(router_address,shitcoin1, ETH, Uint256(1000*base,0), Uint256(10*base,0))     #10,000
    IUni_router.set_reserves(router_address,shitcoin1, USDC, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,shitcoin1, DAI, Uint256(6000*base,0), Uint256(600*base,0))    #6,000
    IUni_router.set_reserves(router_address,shitcoin1, USDT, Uint256(0,0), Uint256(0,0))        #0

    IUni_router.set_reserves(router_address,ETH, USDT, Uint256(100*base,0), Uint256(100000*base,0))       #100,000
    IUni_router.set_reserves(router_address,ETH, USDC, Uint256(10*base,0), Uint256(10000*base,0))         #10,000
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(10,0), Uint256(10000*base,0))          #10,000
    
    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    IUni_router.set_reserves(router_address,ETH, shitcoin2, Uint256(10*base,0), Uint256(1000*base,0))     #10,000
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
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(1000*base,0), Uint256(10000000*base,0))          #1,000,000
    
    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    IUni_router.set_reserves(router_address,ETH, shitcoin2, Uint256(0,0), Uint256(0,0))         #0
    IUni_router.set_reserves(router_address,USDT, shitcoin2, Uint256(5000*base,0), Uint256(500*base,0))   #5000    
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

    IUni_router.set_reserves(router_address,ETH, shitcoin2, Uint256(8*base,0), Uint256(80*base,0))     #8,000
    IUni_router.set_reserves(router_address,USDT, shitcoin2, Uint256(0,0), Uint256(0,0))        #0    
    IUni_router.set_reserves(router_address,USDC, shitcoin2, Uint256(0,0), Uint256(0,0))        #0
    IUni_router.set_reserves(router_address,DAI, shitcoin2, Uint256(50000*base,0), Uint256(5000*base,0))         #50,000

    return(router_address)
end
