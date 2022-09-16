%lang starknet

from protostar.asserts import assert_eq

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, sqrt
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
from src.lib.constants import MAX_FELT, JediSwap, SithSwap, SithSwapStable
from src.interfaces.IRouter_aggregator import IRouter_aggregator
from src.interfaces.ISolver import ISolver
from src.interfaces.ISpf_solver import ISpf_solver
from src.interfaces.ISolver_registry import ISolver_registry
from src.interfaces.IEmpiric_oracle import IEmpiric_oracle
from src.interfaces.IERC20 import IERC20
from src.interfaces.IRouter import IJedi_router, ISith_router
from src.interfaces.IHub import IHub

const Vertices = 6;
const Edges = 21;

const base = 1000000000000000000;  // 1e18
const small_base = 1000000;  // 1e6
const extra_base = 100000000000000000000;  // We use this to artificialy increase the weight of each edge, so that we can subtract the last edges without causeing underflows

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local public_key_0 = 111813453203092678575228394645067365508785178229282836578911214210165801044;
    %{ context.public_key_0 = ids.public_key_0 %}

    // Deploy Mock_Tokens
    local shitcoin1: felt;
    %{ ids.shitcoin1 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12343,343,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.shitcoin1 = ids.shitcoin1 %}
    // %{ print("shitcoin1 Address: ",ids.shitcoin1) %}
    local shitcoin2: felt;
    %{ ids.shitcoin2 = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12344,344,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.shitcoin2 = ids.shitcoin2 %}
    // %{ print("shitcoin2 Address: ",ids.shitcoin2) %}
    local USDC: felt;
    %{ ids.USDC = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12345,345,6,100000000*ids.small_base,0,ids.public_key_0]).contract_address %}
    %{ context.USDC = ids.USDC %}
    // %{ print("USDC Address: ",ids.USDC) %}
    local ETH: felt;
    %{ ids.ETH = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12346,346,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.ETH = ids.ETH %}
    // %{ print("ETH Address: ",ids.ETH) %}
    local USDT: felt;
    %{ ids.USDT = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12347,347,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.USDT = ids.USDT %}
    // %{ print("USDT Address: ",ids.USDT) %}
    local DAI: felt;
    %{ ids.DAI = deploy_contract("./src/openzeppelin/token/erc20/ERC20.cairo", [12348,348,18,100000000*ids.base,0,ids.public_key_0]).contract_address %}
    %{ context.DAI = ids.DAI %}
    // %{ print("DAI Address: ",ids.DAI) %}

    // Deploy Hub
    local hub_address: felt;
    %{
        declared = declare("./src/hub.cairo")
        prepared = prepare(declared, [ids.public_key_0])
        stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=prepared.contract_address)
        deploy(prepared)
        ids.hub_address = prepared.contract_address
        context.hub_address = prepared.contract_address
        stop_prank_callable()
    %}

    // Deploy Solver Registry
    local solver_registry_address: felt;
    %{
        declared = declare("./src/solver_registry.cairo")
        prepared = prepare(declared, [ids.public_key_0])
        stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=prepared.contract_address)
        deploy(prepared)
        ids.solver_registry_address = prepared.contract_address
        context.solver_registry_address = prepared.contract_address
        stop_prank_callable()
    %}

    // Set solver_registry in Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    IHub.set_solver_registry(hub_address, solver_registry_address);
    %{ stop_prank_callable() %}

    // Generate Executor Hash
    local executioner_hash: felt;
    %{
        declared = declare("./src/trade_executor.cairo")
        prepared = prepare(declared, [])
        # constructor will be affected by prank
        deploy(prepared)
        ids.executioner_hash = prepared.class_hash
    %}

    // Set Executor Hash
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    IHub.set_executor(hub_address, executioner_hash);
    %{ stop_prank_callable() %}

    // Deploy Router Aggregator
    local router_aggregator_hash: felt;
    %{
        declared = declare("./src/router_aggregators/router_aggregator.cairo")
        ids.router_aggregator_hash = declared.class_hash
    %}

    // Deploy Router Aggregator Proxy
    local router_aggregator_proxy_address: felt;
    %{
        declared = declare("./src/router_aggregators/router_proxy.cairo")
        prepared = prepare(declared, [ids.router_aggregator_hash,ids.public_key_0,ids.public_key_0])
        stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=prepared.contract_address)
        deploy(prepared)
        ids.router_aggregator_proxy_address = prepared.contract_address
        context.router_aggregator_proxy_address = prepared.contract_address
        stop_prank_callable()
    %}

    // Set routers
    let (local router_1_address) = create_jedi_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );
    // %{ print("Router 1: ",ids.router_1_address) %}
    let (local router_2_address) = create_sith_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );
    // %{ print("Router 2: ",ids.router_2_address) %}
    let (local router_3_address) = create_sith_stable_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );
    // %{ print("Router 3: ",ids.router_3_address) %}

    %{ context.router_1_address = ids.router_1_address %}
    %{ context.router_2_address = ids.router_2_address %}
    %{ context.router_3_address = ids.router_3_address %}

    // Deploy Price Oracle
    local mock_oracle_address: felt;
    %{
        context.mock_oracle_address = deploy_contract("./src/mocks/mock_price_oracle.cairo", []).contract_address 
        ids.mock_oracle_address = context.mock_oracle_address
    %}

    // Set Global Prices for Mock ERC20s in Mock_Price_Feed
    %{ stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=ids.mock_oracle_address) %}
    // ETH/USD, key: 28556963469423460
    IEmpiric_oracle.set_token_price(mock_oracle_address, 28556963469423460, 0, 1000 * base, 18);
    // USDC/USD, key: 8463218501920060260
    IEmpiric_oracle.set_token_price(mock_oracle_address, 8463218501920060260, 0, 1 * base, 18);
    // USDT/USD, key: 8463218574934504292
    IEmpiric_oracle.set_token_price(mock_oracle_address, 8463218574934504292, 0, 1 * base, 18);
    // DAI/USD, key: 28254602066752356
    IEmpiric_oracle.set_token_price(mock_oracle_address, 28254602066752356, 0, 1 * base, 18);
    // Shitcoin1/USD, key: 99234898239
    IEmpiric_oracle.set_token_price(mock_oracle_address, 99234898239, 0, 10 * base, 18);
    // Shitcoin2/USD, key: 23674728373
    IEmpiric_oracle.set_token_price(mock_oracle_address, 23674728373, 0, 10 * base, 18);
    %{ stop_prank_callable() %}

    // Add newly created routers to router aggregator
    %{ stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=ids.router_aggregator_proxy_address) %}
    IRouter_aggregator.add_router(router_aggregator_proxy_address, router_1_address, JediSwap);
    IRouter_aggregator.add_router(router_aggregator_proxy_address, router_2_address, SithSwap);
    IRouter_aggregator.add_router(router_aggregator_proxy_address, router_3_address, SithSwapStable);

    // Set Price feeds at the Router
    IRouter_aggregator.set_global_price(
        router_aggregator_proxy_address, ETH, 28556963469423460, mock_oracle_address
    );
    IRouter_aggregator.set_global_price(
        router_aggregator_proxy_address, USDC, 8463218501920060260, mock_oracle_address
    );
    IRouter_aggregator.set_global_price(
        router_aggregator_proxy_address, USDT, 8463218574934504292, mock_oracle_address
    );
    IRouter_aggregator.set_global_price(
        router_aggregator_proxy_address, DAI, 28254602066752356, mock_oracle_address
    );
    IRouter_aggregator.set_global_price(
        router_aggregator_proxy_address, shitcoin1, 99234898239, mock_oracle_address
    );
    IRouter_aggregator.set_global_price(
        router_aggregator_proxy_address, shitcoin2, 23674728373, mock_oracle_address
    );
    %{ stop_prank_callable() %}

    // Deploy Solvers
    local solver1_address: felt;
    %{
        context.solver1_address = deploy_contract("./src/solvers/single_swap_solver.cairo", []).contract_address 
        ids.solver1_address = context.solver1_address
    %}
    local solver2_address: felt;
    %{
        context.solver2_address = deploy_contract("./src/solvers/spf_solver.cairo", [ids.public_key_0]).contract_address 
        ids.solver2_address = context.solver2_address
    %}
    local solver3_address: felt;
    %{
        context.solver3_address = deploy_contract("./src/solvers/heuristic_splitterV2.cairo", [ids.public_key_0]).contract_address 
        ids.solver3_address = context.solver3_address
    %}

    // Configure SPF
    // Set high Liq tokens for spf_solver
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.solver2_address) %}
    ISpf_solver.set_high_liq_tokens(solver2_address, 0, ETH);
    ISpf_solver.set_high_liq_tokens(solver2_address, 1, DAI);
    ISpf_solver.set_high_liq_tokens(solver2_address, 2, USDT);
    ISpf_solver.set_high_liq_tokens(solver2_address, 3, USDC);
    %{ stop_prank_callable() %}

    // Set router_aggregator for solver
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.solver1_address) %}
    ISolver.set_router_aggregator(solver1_address, router_aggregator_proxy_address);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.solver2_address) %}
    ISolver.set_router_aggregator(solver2_address, router_aggregator_proxy_address);
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.solver3_address) %}
    ISolver.set_router_aggregator(solver3_address, router_aggregator_proxy_address);
    %{ stop_prank_callable() %}

    // Add solver to solver_registry
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.solver_registry_address) %}
    ISolver_registry.set_solver(solver_registry_address, 1, solver1_address);
    ISolver_registry.set_solver(solver_registry_address, 2, solver2_address);
    ISolver_registry.set_solver(solver_registry_address, 3, solver3_address);
    %{ stop_prank_callable() %}

    return ();
}

@external
func test_single_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local public_key_0;
    %{ ids.public_key_0 = context.public_key_0 %}

    local hub_address;
    %{ ids.hub_address = context.hub_address %}

    local ETH;
    %{ ids.ETH = context.ETH %}
    local DAI;
    %{ ids.DAI = context.DAI %}
    local USDC;
    %{ ids.USDC = context.USDC %}
    local USDT;
    %{ ids.USDT = context.USDT %}

    local amount_to_trade: Uint256 = Uint256(2 * base, 0);

    let (_amount_out: Uint256) = IHub.get_solver_amount(hub_address, amount_to_trade, ETH, DAI, 1);
    %{ print("Get_out amount: ",ids._amount_out.low) %}

    // Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH, hub_address, amount_to_trade);
    %{ stop_prank_callable() %}

    // Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_with_solver(
        hub_address,
        _token_in=ETH,
        _token_out=DAI,
        _amount_in=amount_to_trade,
        _min_amount_out=_amount_out,
        _to=public_key_0,
        _solver_id=1,
    );
    %{ stop_prank_callable() %}

    %{ print("received_amount: ",ids.received_amount.low) %}
    return ();
}

@external
func test_spf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local public_key_0;
    %{ ids.public_key_0 = context.public_key_0 %}

    local hub_address;
    %{ ids.hub_address = context.hub_address %}

    local ETH;
    %{ ids.ETH = context.ETH %}
    local DAI;
    %{ ids.DAI = context.DAI %}
    local USDC;
    %{ ids.USDC = context.USDC %}
    local USDT;
    %{ ids.USDT = context.USDT %}
    local shitcoin1;
    %{ ids.shitcoin1 = context.shitcoin1 %}
    local shitcoin2;
    %{ ids.shitcoin2 = context.shitcoin2 %}

    local amount_to_trade: Uint256 = Uint256(2 * base, 0);

    let (amount_out: Uint256) = IHub.get_solver_amount(hub_address, amount_to_trade, ETH, DAI, 2);
    %{ print("Get_out amount: ",ids.amount_out.low) %}

    // Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH, hub_address, amount_to_trade);
    %{ stop_prank_callable() %}

    // Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_with_solver(
        hub_address,
        _token_in=ETH,
        _token_out=DAI,
        _amount_in=amount_to_trade,
        _min_amount_out=amount_out,
        _to=public_key_0,
        _solver_id=2,
    );
    %{ stop_prank_callable() %}

    %{ print("received_amount: ",ids.received_amount.low) %}

    return ();
}

@external
func test_heuristic_splitter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local public_key_0;
    %{ ids.public_key_0 = context.public_key_0 %}

    local hub_address;
    %{ ids.hub_address = context.hub_address %}

    local ETH;
    %{ ids.ETH = context.ETH %}
    local DAI;
    %{ ids.DAI = context.DAI %}
    local USDC;
    %{ ids.USDC = context.USDC %}
    local USDT;
    %{ ids.USDT = context.USDT %}

    local amount_to_trade: Uint256 = Uint256(2 * base, 0);

    let (amount_out: Uint256) = IHub.get_solver_amount(hub_address, amount_to_trade, ETH, DAI, 3);
    %{ print("Get_out amount: ",ids.amount_out.low) %}

    // Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH, hub_address, amount_to_trade);
    %{ stop_prank_callable() %}

    // Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_with_solver(
        hub_address,
        _token_in=ETH,
        _token_out=DAI,
        _amount_in=amount_to_trade,
        _min_amount_out=amount_out,
        _to=public_key_0,
        _solver_id=3,
    );
    %{ stop_prank_callable() %}

    %{ print("received_amount: ",ids.received_amount.low) %}

    return ();
}

// @external
func test_view_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local public_key_0;
    %{ ids.public_key_0 = context.public_key_0 %}

    local hub_address;
    %{ ids.hub_address = context.hub_address %}

    local ETH;
    %{ ids.ETH = context.ETH %}
    local DAI;
    %{ ids.DAI = context.DAI %}
    local USDC;
    %{ ids.USDC = context.USDC %}
    local USDT;
    %{ ids.USDT = context.USDT %}
    local shitcoin1;
    %{ ids.shitcoin1 = context.shitcoin1 %}
    local shitcoin2;
    %{ ids.shitcoin2 = context.shitcoin2 %}

    local amount_to_trade: Uint256 = Uint256(2 * base, 0);
    local expected_min_return: Uint256 = Uint256(1 * base, 0);

    // Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH, hub_address, amount_to_trade);
    %{ stop_prank_callable() %}

    // Get amount out
    // Using custom interface
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.get_solver_amount(
        hub_address, _amount_in=amount_to_trade, _token_in=ETH, _token_out=USDC, _solver_id=1
    );

    // Using uni conform interface
    let (path: felt*) = alloc();
    assert path[0] = ETH;
    assert path[1] = USDC;
    let (_, uni_view_amounts: Uint256*) = IHub.get_amounts_out(
        hub_address, amountIn=amount_to_trade, path_len=2, path=path
    );
    %{ stop_prank_callable() %}

    assert uni_view_amounts[1] = received_amount;
    %{ print("received_amount: ",ids.received_amount.low) %}

    return ();
}

func create_jedi_router{syscall_ptr: felt*, range_check_ptr}(
    public_key_0: felt,
    ETH: felt,
    USDC: felt,
    USDT: felt,
    DAI: felt,
    shitcoin1: felt,
    shitcoin2: felt,
) -> (router_address: felt) {
    alloc_locals;

    local router_address: felt;
    // We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_jedi_router.cairo", []).contract_address %}

    // shitcoin1 = 10$
    // ETH = 1000$ ....sadge
    // DAI = 1$
    // USDT = 1$
    // USDC = 1$
    // shitcoin2 = 10$

    // Set Reserves
    IJedi_router.set_reserves(router_address, shitcoin1, ETH, Uint256(10000 * base, 0), Uint256(100 * base, 0));  // 100,000
    IJedi_router.set_reserves(router_address, shitcoin1, DAI, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJedi_router.set_reserves(router_address, ETH, USDT, Uint256(100 * base, 0), Uint256(100000 * base, 0));  // 100,000
    IJedi_router.set_reserves(router_address, ETH, USDC, Uint256(10 * base, 0), Uint256(10000 * small_base, 0));  // 10,000
    IJedi_router.set_reserves(router_address, ETH, DAI, Uint256(10 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJedi_router.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJedi_router.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJedi_router.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    // Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin1) %}
    IERC20.transfer(shitcoin1, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(shitcoin1, router_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.transfer(ETH, router_address, Uint256(100 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(100 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(10 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(10 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
    IERC20.transfer(USDC, router_address, Uint256(10000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
    IERC20.transfer(USDT, router_address, Uint256(100000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
    IERC20.transfer(DAI, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}

    return (router_address,);
}

func create_sith_router{syscall_ptr: felt*, range_check_ptr}(
    public_key_0: felt,
    ETH: felt,
    USDC: felt,
    USDT: felt,
    DAI: felt,
    shitcoin1: felt,
    shitcoin2: felt,
) -> (router_address: felt) {
    alloc_locals;

    local router_address: felt;
    // We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_sith_router.cairo", []).contract_address %}

    // shitcoin1 = 10$
    // ETH = 1000$ ....sadge
    // DAI = 1$
    // USDT = 1$
    // USDC = 1$
    // shitcoin2 = 10$

    IJedi_router.set_reserves(router_address, ETH, DAI, Uint256(1000 * base, 0), Uint256(1000000 * base, 0));  // 1,000,000

    IJedi_router.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJedi_router.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJedi_router.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    // Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.transfer(ETH, router_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
    IERC20.transfer(USDT, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
    IERC20.transfer(DAI, router_address, Uint256(1000000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}

    return (router_address,);
}

func create_sith_stable_router{syscall_ptr: felt*, range_check_ptr}(
    public_key_0: felt,
    ETH: felt,
    USDC: felt,
    USDT: felt,
    DAI: felt,
    shitcoin1: felt,
    shitcoin2: felt,
) -> (router_address: felt) {
    alloc_locals;

    local router_address: felt;
    // We deploy contract and put its address into a local variable. Second argument is calldata array
    %{ ids.router_address = deploy_contract("./src/mocks/mock_sith_router.cairo", []).contract_address %}

    // shitcoin1 = 10$
    // ETH = 1000$ ....sadge
    // DAI = 1$
    // USDT = 1$
    // USDC = 1$
    // shitcoin2 = 10$

    IJedi_router.set_reserves(router_address, shitcoin1, USDT, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJedi_router.set_reserves(router_address, ETH, USDC, Uint256(10 * base, 0), Uint256(10000 * small_base, 0));  // 10,000
    IJedi_router.set_reserves(router_address, ETH, DAI, Uint256(100 * base, 0), Uint256(100000 * base, 0));  // 100,000

    IJedi_router.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJedi_router.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJedi_router.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    IJedi_router.set_reserves(router_address, shitcoin2, DAI, Uint256(10000 * base, 0), Uint256(100000 * base, 0));  // 100,000
    IJedi_router.set_reserves(router_address, shitcoin2, USDT, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    // Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin2) %}
    IERC20.transfer(shitcoin2, router_address, Uint256(1000 * base, 0));
    IERC20.transfer(shitcoin2, router_address, Uint256(10000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.shitcoin1) %}
    IERC20.transfer(shitcoin1, router_address, Uint256(1000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.transfer(ETH, router_address, Uint256(10 * base, 0));
    IERC20.transfer(ETH, router_address, Uint256(100 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDC) %}
    IERC20.transfer(USDC, router_address, Uint256(10000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    IERC20.transfer(USDC, router_address, Uint256(80000 * small_base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.USDT) %}
    IERC20.transfer(USDT, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(10000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(USDT, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.DAI) %}
    IERC20.transfer(DAI, router_address, Uint256(100000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(100000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(80000 * base, 0));
    IERC20.transfer(DAI, router_address, Uint256(90000 * base, 0));
    %{ stop_prank_callable() %}

    return (router_address,);
}
