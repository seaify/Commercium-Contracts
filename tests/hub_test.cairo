%lang starknet

from protostar.asserts import (assert_eq)

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, sqrt
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.bitwise import bitwise_or
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (Uint256,uint256_le,uint256_eq,uint256_add,uint256_sub,uint256_mul,uint256_signed_div_rem,uint256_unsigned_div_rem)

from src.lib.hub import Uni
from src.lib.array import Array
from src.lib.utils import Utils
from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.ISolver import ISolver
from src.interfaces.ISolver_registry import ISolver_registry
from src.interfaces.IERC20 import IERC20
from src.interfaces.IUni_router import IUni_router
from src.interfaces.ISpf_solver import ISpf_solver
from src.interfaces.IHub import IHub

const Vertices = 6
const Edges = 21
const LARGE_VALUE = 850705917302346000000000000000000000000000000 

const base = 1000000000000000000 # 1e18
const extra_base = 100000000000000000000 # We use this to artificialy increase the weight of each edge, so that we can subtract the last edges without causeing underflows

@external
func __setup__{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    local public_key_0 = 111813453203092678575228394645067365508785178229282836578911214210165801044

    #Deploy Mock_Tokens
    local shitcoin1 : felt
    %{ ids.shitcoin1 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12343,343,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.shitcoin1 = ids.shitcoin1 %}
    %{ print("shitcoin1 Address: ",ids.shitcoin1) %}
    local shitcoin2 : felt
    %{ ids.shitcoin2 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12344,344,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.shitcoin2 = ids.shitcoin2 %}
    %{ print("shitcoin2 Address: ",ids.shitcoin2) %}
    local USDC : felt
    %{ ids.USDC = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12345,345,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.USDC = ids.USDC %}
    %{ print("USDC Address: ",ids.USDC) %}
    local ETH : felt
    %{ ids.ETH = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12346,346,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.ETH = ids.ETH %}
    %{ print("ETH Address: ",ids.ETH) %}
    local USDT : felt
    %{ ids.USDT = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12347,347,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.USDT = ids.USDT %}
    %{ print("USDT Address: ",ids.USDT) %}
    local DAI : felt
    %{ ids.DAI = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12348,348,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.DAI = ids.DAI %}
    %{ print("DAI Address: ",ids.DAI) %}

    #Deploy Hub
    local hub_address : felt
    %{
        declared = declare("./src/hub.cairo")
        prepared = prepare(declared, [ids.public_key_0])
        stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=prepared.contract_address)
        deploy(prepared)
        ids.hub_address = prepared.contract_address
        context.hub_address = prepared.contract_address
        stop_prank_callable()
    %}

    #Deploy Solver Registry
    local solver_registry_address : felt
    %{
        declared = declare("./src/solver_registry.cairo")
        prepared = prepare(declared, [ids.public_key_0])
        stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=prepared.contract_address)
        deploy(prepared)
        ids.solver_registry_address = prepared.contract_address
        context.solver_registry_address = prepared.contract_address
        stop_prank_callable()
    %}

    #Set solver_registry in Hub
    %{stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address)%}
    IHub.set_solver_registry(hub_address,solver_registry_address)
    %{stop_prank_callable()%}

    #Generate Executor Hash
    local executioner_hash: felt
    %{
        declared = declare("./src/trade_executioner.cairo")
        prepared = prepare(declared, [])
        stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=prepared.contract_address)
        # constructor will be affected by prank
        deploy(prepared)
        ids.executioner_hash = prepared.class_hash
        stop_prank_callable()
    %}

    #Set Executor Hash
    %{stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address)%}
        IHub.set_executor(hub_address,executioner_hash)
    %{stop_prank_callable()%}

    #Deploy Router Aggregator
    local router_aggregator_address : felt
    %{
        declared = declare("./src/router_aggregators/router_aggregatorV2.cairo")
        prepared = prepare(declared, [ids.public_key_0])
        stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=prepared.contract_address)
        deploy(prepared)
        ids.router_aggregator_address = prepared.contract_address
        context.router_aggregator_address = prepared.contract_address
        stop_prank_callable()
    %}

    # Set routers
    let (local router_1_address) = create_router1(public_key_0,ETH,USDC,USDT,DAI,shitcoin1,shitcoin2)
    %{ print("Router 1: ",ids.router_1_address) %}
    let (local router_2_address) = create_router2(public_key_0,ETH,USDC,USDT,DAI,shitcoin1,shitcoin2)
    %{ print("Router 2: ",ids.router_2_address) %}
    let (local router_3_address) = create_router3(public_key_0,ETH,USDC,USDT,DAI,shitcoin1,shitcoin2)
    %{ print("Router 3: ",ids.router_3_address) %}

    %{ context.router_1_address = ids.router_1_address %}
    %{ context.router_2_address = ids.router_2_address %}
    %{ context.router_3_address = ids.router_3_address %}

    # Add newly created routers to router aggregator
    %{ stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=ids.router_aggregator_address) %}
    IRouter_aggregator.add_router(router_aggregator_address,router_1_address,Uni)
    IRouter_aggregator.add_router(router_aggregator_address,router_2_address,Uni)
    IRouter_aggregator.add_router(router_aggregator_address,router_3_address,Uni)  
    
    # Set Global Prices for Mock ERC20s in router aggregator
    IRouter_aggregator.set_global_price(router_aggregator_address,ETH,Uint256(1000*base,0))
    IRouter_aggregator.set_global_price(router_aggregator_address,USDC,Uint256(1*base,0))
    IRouter_aggregator.set_global_price(router_aggregator_address,USDT,Uint256(1*base,0))
    IRouter_aggregator.set_global_price(router_aggregator_address,DAI,Uint256(1*base,0))
    IRouter_aggregator.set_global_price(router_aggregator_address,shitcoin1,Uint256(10*base,0))
    IRouter_aggregator.set_global_price(router_aggregator_address,shitcoin2,Uint256(10*base,0))
    %{ stop_prank_callable() %}

    #let (return_amount: Uint256) = IUni_router.get_amount_out(router_1_address,Uint256(100,0), shitcoin1, ETH)
    #let (_,local router_res,_) = IRouter_aggregator.get_single_best_pool(router_aggregator_address,Uint256(1000,0), shitcoin1, ETH)
    #with_attr error_message("router_res: {router_res} router_1_address: {router_1_address} router_2_address: {router_2_address} router_3_address: {router_3_address}"):
    #    assert 1 = 2
    #end

    #Deploy Solvers
    local solver1_address : felt
    %{ 
        context.solver1_address = deploy_contract("./src/solvers/single_swap_solver.cairo", []).contract_address 
        ids.solver1_address = context.solver1_address
    %}
    local solver2_address : felt
    %{ 
        context.solver2_address = deploy_contract("./src/solvers/spf_solver.cairo", []).contract_address 
        ids.solver2_address = context.solver2_address
    %}
    
    #Set router_aggregator for solver
    %{stop_prank_callable = start_prank(ids.public_key_0,ids.solver1_address)%}
        ISolver.set_router_aggregator(solver1_address,router_aggregator_address)
    %{stop_prank_callable()%}
    %{stop_prank_callable = start_prank(ids.public_key_0,ids.solver2_address)%}
        ISolver.set_router_aggregator(solver2_address,router_aggregator_address)
    %{stop_prank_callable()%}

    #Add solver to solver_registry
    %{stop_prank_callable = start_prank(ids.public_key_0,ids.solver_registry_address)%}
        ISolver_registry.set_solver(solver_registry_address,1,solver1_address)
        ISolver_registry.set_solver(solver_registry_address,2,solver2_address)
    %{stop_prank_callable()%}

    return ()
end

@external
func test_single_swap{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    local public_key_0 = 111813453203092678575228394645067365508785178229282836578911214210165801044

    local hub_address
    %{ ids.hub_address = context.hub_address %}

    local ETH
    %{ ids.ETH = context.ETH %}
    local DAI
    %{ ids.DAI = context.DAI %}
    local USDC
    %{ ids.USDC = context.USDC %}
    local USDT
    %{ ids.USDT = context.USDT %}

    local amount_to_trade: Uint256 = Uint256(100*base,0)
    local expected_min_return: Uint256 = Uint256(80*base,0)

    local router_aggregator_address
    %{ ids.router_aggregator_address = context.router_aggregator_address %}

    #Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH,hub_address,amount_to_trade)
    %{ stop_prank_callable() %}

    #Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_with_solver(
        hub_address,
        _token_in=ETH, 
        _token_out=DAI, 
        _amount_in=amount_to_trade, 
        _min_amount_out=expected_min_return, 
        _solver_id=1
    )
    %{ stop_prank_callable() %}

    %{ print("received_amount: ",ids.received_amount.low) %}

    return()
end

@external
func test_spf{
    syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*, 
    range_check_ptr}():
    alloc_locals

    local public_key_0 = 111813453203092678575228394645067365508785178229282836578911214210165801044

    local hub_address
    %{ ids.hub_address = context.hub_address %}

    local ETH
    %{ ids.ETH = context.ETH %}
    local DAI
    %{ ids.DAI = context.DAI %}
    local USDC
    %{ ids.USDC = context.USDC %}
    local USDT
    %{ ids.USDT = context.USDT %}
    local shitcoin1
    %{ ids.shitcoin1 = context.shitcoin1 %}
    local shitcoin2
    %{ ids.shitcoin2 = context.shitcoin2 %}

    local amount_to_trade: Uint256 = Uint256(100*base,0)
    local expected_min_return: Uint256 = Uint256(75*base,0)

    local router_aggregator_address
    %{ ids.router_aggregator_address = context.router_aggregator_address %}

    #Set high Liq tokens for spf_solver
    local solver2_address
    %{ids.solver2_address = context.solver2_address %}
    %{stop_prank_callable = start_prank(ids.public_key_0,ids.solver2_address)%}
        ISolver.set_high_liq_tokens(solver2_address,0,ETH)
        ISolver.set_high_liq_tokens(solver2_address,1,DAI)
        ISolver.set_high_liq_tokens(solver2_address,2,USDT)
        ISolver.set_high_liq_tokens(solver2_address,3,USDC)
    %{stop_prank_callable()%}

    #Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin1) %}
    IERC20.approve(shitcoin1,hub_address,amount_to_trade)
    %{ stop_prank_callable() %}

    #Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_with_solver(
        hub_address,
        _token_in=shitcoin1, 
        _token_out=shitcoin2, 
        _amount_in=amount_to_trade, 
        _min_amount_out=expected_min_return, 
        _solver_id=2
    )
    %{ stop_prank_callable() %}

    %{ print("received_amount: ",ids.received_amount.low) %}

    return()
end

func create_router1{syscall_ptr : felt*, range_check_ptr}(
        public_key_0: felt,
        ETH: felt,
        USDC: felt,
        USDT: felt,
        DAI: felt,
        shitcoin1: felt,
        shitcoin2: felt
    ) -> (router_address:felt):
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

    #Set Reserves
    IUni_router.set_reserves(router_address,shitcoin1, ETH, Uint256(10000*base,0), Uint256(100*base,0))       #100,000
    IUni_router.set_reserves(router_address,shitcoin1, DAI, Uint256(1000*base,0), Uint256(10000*base,0))         #10,000

    IUni_router.set_reserves(router_address,ETH, USDT, Uint256(100*base,0), Uint256(100000*base,0))       #100,000
    IUni_router.set_reserves(router_address,ETH, USDC, Uint256(10*base,0), Uint256(10000*base,0))         #10,000
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(10*base,0), Uint256(10000*base,0))          #10,000

    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    #Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin1) %}
        IERC20.transfer(shitcoin1,router_address,Uint256(10000*base,0))
        IERC20.transfer(shitcoin1,router_address,Uint256(1000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
        IERC20.transfer(ETH,router_address,Uint256(100*base,0))
        IERC20.transfer(ETH,router_address,Uint256(100*base,0))
        IERC20.transfer(ETH,router_address,Uint256(10*base,0))
        IERC20.transfer(ETH,router_address,Uint256(10*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
        IERC20.transfer(USDC,router_address,Uint256(10000*base,0))
        IERC20.transfer(USDC,router_address,Uint256(80000*base,0))
        IERC20.transfer(USDC,router_address,Uint256(80000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
        IERC20.transfer(USDT,router_address,Uint256(100000*base,0))
        IERC20.transfer(USDT,router_address,Uint256(80000*base,0))
        IERC20.transfer(USDT,router_address,Uint256(90000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
        IERC20.transfer(DAI,router_address,Uint256(10000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(10000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(80000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(90000*base,0))
    %{ stop_prank_callable() %}

    return(router_address)
end

func create_router2{syscall_ptr : felt*, range_check_ptr}(
        public_key_0: felt,
        ETH: felt,
        USDC: felt,
        USDT: felt,
        DAI: felt,
        shitcoin1: felt,
        shitcoin2: felt
    ) -> (router_address:felt):
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
    
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(1000*base,0), Uint256(1000000*base,0))          #1,000,000
    
    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    #Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
        IERC20.transfer(ETH,router_address,Uint256(1000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
        IERC20.transfer(USDC,router_address,Uint256(80000*base,0))
        IERC20.transfer(USDC,router_address,Uint256(80000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
        IERC20.transfer(USDT,router_address,Uint256(80000*base,0))
        IERC20.transfer(USDT,router_address,Uint256(90000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
        IERC20.transfer(DAI,router_address,Uint256(1000000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(80000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(90000*base,0))
    %{ stop_prank_callable() %}

    return(router_address)
end

func create_router3{syscall_ptr : felt*, range_check_ptr}(
        public_key_0: felt,
        ETH: felt,
        USDC: felt,
        USDT: felt,
        DAI: felt,
        shitcoin1: felt,
        shitcoin2: felt
    ) -> (router_address:felt):
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

    IUni_router.set_reserves(router_address,shitcoin1, USDT, Uint256(1000*base,0), Uint256(10000*base,0))       #10,000

    IUni_router.set_reserves(router_address,ETH, USDT, Uint256(100*base,0), Uint256(100000*base,0))       #100,000
    IUni_router.set_reserves(router_address,ETH, USDC, Uint256(10*base,0), Uint256(10000*base,0))         #10,000
    IUni_router.set_reserves(router_address,ETH, DAI, Uint256(100*base,0), Uint256(100000*base,0))          #100,000
    
    IUni_router.set_reserves(router_address,USDT, USDC, Uint256(80000*base,0), Uint256(80000*base,0))     #80,000
    IUni_router.set_reserves(router_address,USDT, DAI, Uint256(90000*base,0), Uint256(90000*base,0))      #90,000
    
    IUni_router.set_reserves(router_address,USDC, DAI, Uint256(80000*base,0), Uint256(80000*base,0))      #80,000

    IUni_router.set_reserves(router_address,shitcoin2, DAI, Uint256(10000*base,0), Uint256(100000*base,0))       #100,000
    IUni_router.set_reserves(router_address,shitcoin2, USDT, Uint256(1000*base,0), Uint256(10000*base,0))       #10,000

    #Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin2) %}
        IERC20.transfer(shitcoin2,router_address,Uint256(1000*base,0))
        IERC20.transfer(shitcoin2,router_address,Uint256(10000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin1) %}
        IERC20.transfer(shitcoin1,router_address,Uint256(1000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
        IERC20.transfer(ETH,router_address,Uint256(100*base,0))
        IERC20.transfer(ETH,router_address,Uint256(10*base,0))
        IERC20.transfer(ETH,router_address,Uint256(100*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
        IERC20.transfer(USDC,router_address,Uint256(10000*base,0))
        IERC20.transfer(USDC,router_address,Uint256(80000*base,0))
        IERC20.transfer(USDC,router_address,Uint256(80000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
        IERC20.transfer(USDT,router_address,Uint256(10000*base,0))
        IERC20.transfer(USDT,router_address,Uint256(10000*base,0))
        IERC20.transfer(USDT,router_address,Uint256(100000*base,0))
        IERC20.transfer(USDT,router_address,Uint256(80000*base,0))
        IERC20.transfer(USDT,router_address,Uint256(90000*base,0))
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
        IERC20.transfer(DAI,router_address,Uint256(100000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(100000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(80000*base,0))
        IERC20.transfer(DAI,router_address,Uint256(90000*base,0))
    %{ stop_prank_callable() %}

    return(router_address)
end