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
from src.lib.constants import MAX_FELT, JediSwap, SithSwap, TenK, AlphaRoad
from src.interfaces.i_router_aggregator import IRouterAggregator
from src.interfaces.i_solver import ISolver
from src.interfaces.i_spf_solver import ISpfSolver
from src.interfaces.i_solver_registry import ISolverRegistry
from src.interfaces.i_empiric_oracle import IEmpiricOracle
from src.interfaces.i_erc20 import IERC20
from src.interfaces.i_router import IJediRouter, ISithRouter, IAlphaRouter
from src.interfaces.i_hub import IHub
from src.interfaces.i_pool import IAlphaPool
from src.lib.utils import Router, Path

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
    let (local router_3_address) = create_TenK_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );
    // %{ print("Router 3: ",ids.router_3_address) %}
    let (local router_4_address) = create_alpha_router(
        public_key_0, ETH, USDC, USDT, DAI, shitcoin1, shitcoin2
    );

    %{ context.router_1_address = ids.router_1_address %}
    %{ context.router_2_address = ids.router_2_address %}
    %{ context.router_3_address = ids.router_3_address %}
    %{ context.router_4_address = ids.router_4_address %}

    // Deploy Price Oracle
    local mock_oracle_address: felt;
    %{
        context.mock_oracle_address = deploy_contract("./src/mocks/mock_price_oracle.cairo", []).contract_address 
        ids.mock_oracle_address = context.mock_oracle_address
    %}

    // Set Global Prices for Mock ERC20s in Mock_Price_Feed
    %{ stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=ids.mock_oracle_address) %}
    // ETH/USD, key: 28556963469423460
    IEmpiricOracle.set_token_price(mock_oracle_address, 28556963469423460, 0, 1000 * base, 18);
    // USDC/USD, key: 8463218501920060260
    IEmpiricOracle.set_token_price(mock_oracle_address, 8463218501920060260, 0, 1 * base, 18);
    // USDT/USD, key: 8463218574934504292
    IEmpiricOracle.set_token_price(mock_oracle_address, 8463218574934504292, 0, 1 * base, 18);
    // DAI/USD, key: 28254602066752356
    IEmpiricOracle.set_token_price(mock_oracle_address, 28254602066752356, 0, 1 * base, 18);
    // Shitcoin1/USD, key: 99234898239
    IEmpiricOracle.set_token_price(mock_oracle_address, 99234898239, 0, 10 * base, 18);
    // Shitcoin2/USD, key: 23674728373
    IEmpiricOracle.set_token_price(mock_oracle_address, 23674728373, 0, 10 * base, 18);
    %{ stop_prank_callable() %}

    // Add newly created routers to router aggregator
    %{ stop_prank_callable = start_prank(ids.public_key_0, target_contract_address=ids.router_aggregator_proxy_address) %}
    IRouterAggregator.add_router(router_aggregator_proxy_address, router_1_address, JediSwap);
    IRouterAggregator.add_router(router_aggregator_proxy_address, router_2_address, SithSwap);
    IRouterAggregator.add_router(router_aggregator_proxy_address, router_3_address, TenK);
    IRouterAggregator.add_router(router_aggregator_proxy_address, router_4_address, AlphaRoad);

    // Set Price feeds at the Router
    IRouterAggregator.set_global_price(
        router_aggregator_proxy_address, ETH, 28556963469423460, mock_oracle_address
    );
    IRouterAggregator.set_global_price(
        router_aggregator_proxy_address, USDC, 8463218501920060260, mock_oracle_address
    );
    //IRouterAggregator.set_global_price(
    //    router_aggregator_proxy_address, USDT, 8463218574934504292, mock_oracle_address
    //);
    IRouterAggregator.set_global_price(
        router_aggregator_proxy_address, DAI, 28254602066752356, mock_oracle_address
    );
    //IRouterAggregator.set_global_price(
    //    router_aggregator_proxy_address, shitcoin1, 99234898239, mock_oracle_address
    //);
    //IRouterAggregator.set_global_price(
    //    router_aggregator_proxy_address, shitcoin2, 23674728373, mock_oracle_address
    //);
    %{ stop_prank_callable() %}

    // Deploy Solvers
    local solver1_address: felt;
    %{
        context.solver1_address = deploy_contract("./src/solvers/single_swap_solver.cairo", [ids.router_aggregator_proxy_address]).contract_address 
        ids.solver1_address = context.solver1_address
    %}
    local solver2_address: felt;
    %{
        context.solver2_address = deploy_contract("./src/solvers/spf_solver.cairo", [ids.public_key_0,ids.router_aggregator_proxy_address]).contract_address 
        ids.solver2_address = context.solver2_address
    %}
    local solver3_address: felt;
    %{
        context.solver3_address = deploy_contract("./src/solvers/heuristic_splitterV2.cairo", [ids.router_aggregator_proxy_address]).contract_address 
        ids.solver3_address = context.solver3_address
    %}

    // Configure SPF
    // Set high Liq tokens for spf_solver
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.solver2_address) %}
    ISpfSolver.set_high_liq_tokens(solver2_address, 0, ETH);
    ISpfSolver.set_high_liq_tokens(solver2_address, 1, DAI);
    //ISpfSolver.set_high_liq_tokens(solver2_address, 2, USDT);
    ISpfSolver.set_high_liq_tokens(solver2_address, 2, USDC);
    %{ stop_prank_callable() %}

    // Add solver to solver_registry
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.solver_registry_address) %}
    ISolverRegistry.set_solver(solver_registry_address, 1, solver1_address);
    ISolverRegistry.set_solver(solver_registry_address, 2, solver2_address);
    ISolverRegistry.set_solver(solver_registry_address, 3, solver3_address);
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

    local amount_to_trade: Uint256 = Uint256(100 * base, 0);

    let (_amount_out: Uint256) = IHub.get_amount_out_with_solver(hub_address, amount_to_trade, ETH, DAI, 1);
    %{ print("Get_out amount: ",ids._amount_out.low) %}

    // Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH, hub_address, amount_to_trade);
    %{ stop_prank_callable() %}

    // Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_exact_tokens_for_tokens_with_solver(
        hub_address,
        _amount_in=amount_to_trade,
        _min_amount_out=_amount_out,
        _token_in=ETH,
        _token_out=DAI,
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

    let (amount_out: Uint256) = IHub.get_amount_out_with_solver(hub_address, amount_to_trade, ETH, DAI, 2);
    %{ print("Get_out amount: ",ids.amount_out.low) %}

    // Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH, hub_address, amount_to_trade);
    %{ stop_prank_callable() %}

    // Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_exact_tokens_for_tokens_with_solver(
        hub_address,
        _amount_in=amount_to_trade,
        _min_amount_out=amount_out,
        _token_in=ETH,
        _token_out=DAI,
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

    let (amount_out: Uint256) = IHub.get_amount_out_with_solver(hub_address, amount_to_trade, ETH, USDC, 3);
    %{ print("Get_out amount: ",ids.amount_out.low) %}

    // Allow hub to take tokens
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.approve(ETH, hub_address, amount_to_trade);
    %{ stop_prank_callable() %}

    // Execute Solver via Hub
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.hub_address) %}
    let (received_amount: Uint256) = IHub.swap_exact_tokens_for_tokens_with_solver(
        hub_address,
        _amount_in=amount_to_trade,
        _min_amount_out=amount_out,
        _token_in=ETH,
        _token_out=USDC,
        _to=public_key_0,
        _solver_id=3,
    );
    %{ stop_prank_callable() %}

    %{ print("received_amount: ",ids.received_amount.low) %}

    return ();
}

@external
func test_swap_with_path{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
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

    let (
        routers_len: felt,
        routers: Router*,
        path_len: felt,
        path: Path*,
        amounts_len: felt,
        amounts: felt*,
        amount_out: Uint256
    ) = IHub.get_amount_and_path_with_solver(hub_address, amount_to_trade, ETH, DAI, 2);
    
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
    let (received_amount: Uint256) = IHub.get_amount_out_with_solver(
        hub_address, _amount_in=amount_to_trade, _token_in=ETH, _token_out=USDC, _solver_id=1
    );

    // Using uni conform interface
    let (return_amount: Uint256) = IHub.get_amount_out(
        hub_address, amount_to_trade, ETH, DAI
    );
    %{ stop_prank_callable() %}

    %{ print("received_amount: ",ids.return_amount.low) %}

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
    IJediRouter.set_reserves(router_address, shitcoin1, ETH, Uint256(10000 * base, 0), Uint256(100 * base, 0));  // 100,000
    IJediRouter.set_reserves(router_address, shitcoin1, DAI, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJediRouter.set_reserves(router_address, ETH, USDT, Uint256(100 * base, 0), Uint256(100000 * base, 0));  // 100,000
    IJediRouter.set_reserves(router_address, ETH, USDC, Uint256(10 * base, 0), Uint256(10000 * small_base, 0));  // 10,000
    IJediRouter.set_reserves(router_address, ETH, DAI, Uint256(10 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJediRouter.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJediRouter.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJediRouter.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

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

func create_alpha_router{syscall_ptr: felt*, range_check_ptr}(
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
    %{ ids.router_address = deploy_contract("./src/mocks/mock_alpha_router.cairo", []).contract_address %}

    local eth_dai_pair: felt;
    %{ ids.eth_dai_pair = deploy_contract("./src/mocks/mock_alpha_pair.cairo", []).contract_address %}
    
    local eth_usdt_pair: felt;
    %{ ids.eth_usdt_pair = deploy_contract("./src/mocks/mock_alpha_pair.cairo", []).contract_address %}

    local eth_usdc_pair: felt;
    %{ ids.eth_usdc_pair = deploy_contract("./src/mocks/mock_alpha_pair.cairo", []).contract_address %}

    local dai_usdc_pair: felt;
    %{ ids.dai_usdc_pair = deploy_contract("./src/mocks/mock_alpha_pair.cairo", []).contract_address %}

    local dai_usdt_pair: felt;
    %{ ids.dai_usdt_pair = deploy_contract("./src/mocks/mock_alpha_pair.cairo", []).contract_address %}

    local usdc_usdt_pair: felt;
    %{ ids.usdc_usdt_pair = deploy_contract("./src/mocks/mock_alpha_pair.cairo", []).contract_address %}

    // shitcoin1 = 10$
    // ETH = 1000$ ....sadge
    // DAI = 1$
    // USDT = 1$
    // USDC = 1$
    // shitcoin2 = 10$


    //CONFIGURE ROUTER AND PAIRS
    IAlphaRouter.set_pair(router_address, ETH, DAI, eth_dai_pair);
    IAlphaRouter.set_pair(router_address, ETH, USDC, eth_usdc_pair);
    IAlphaRouter.set_pair(router_address, ETH, USDT, eth_usdt_pair);
    IAlphaRouter.set_pair(router_address, DAI, USDC, dai_usdc_pair);
    IAlphaRouter.set_pair(router_address, DAI, USDT, dai_usdt_pair);
    IAlphaRouter.set_pair(router_address, USDC, USDT, usdc_usdt_pair);

    IAlphaPool.set_token0(eth_dai_pair,ETH);
    IAlphaPool.set_token0(eth_usdc_pair,ETH);
    IAlphaPool.set_token0(eth_usdt_pair,ETH);
    IAlphaPool.set_token0(dai_usdc_pair,DAI);
    IAlphaPool.set_token0(dai_usdt_pair,DAI);
    IAlphaPool.set_token0(usdc_usdt_pair,USDC);


    //1: ETH 2: DAI
    IAlphaPool.set_reserves(eth_dai_pair, Uint256(100000 * base, 0), Uint256(100000000 * base, 0));  // 100,000,000

    //1: USDT 2: USDC
    IAlphaPool.set_reserves(usdc_usdt_pair, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    //1: USDT 2: DAI
    IAlphaPool.set_reserves(dai_usdt_pair, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    //1: USDC 2: DAI
    IAlphaPool.set_reserves(dai_usdc_pair, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    // Transfer tokens to router
    %{ stop_prank_callable = start_prank(ids.public_key_0,ids.ETH) %}
    IERC20.transfer(ETH, router_address, Uint256(100000 * base, 0));
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

    IJediRouter.set_reserves(router_address, ETH, DAI, Uint256(1000 * base, 0), Uint256(1000000 * base, 0));  // 1,000,000

    IJediRouter.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJediRouter.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJediRouter.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

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

func create_TenK_router{syscall_ptr: felt*, range_check_ptr}(
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
    %{ ids.router_address = deploy_contract("./src/mocks/mock_TenK_router.cairo", []).contract_address %}

    // shitcoin1 = 10$
    // ETH = 1000$ ....sadge
    // DAI = 1$
    // USDT = 1$
    // USDC = 1$
    // shitcoin2 = 10$

    IJediRouter.set_reserves(router_address, shitcoin1, USDT, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

    IJediRouter.set_reserves(router_address, ETH, USDC, Uint256(10 * base, 0), Uint256(10000 * small_base, 0));  // 10,000
    IJediRouter.set_reserves(router_address, ETH, DAI, Uint256(100 * base, 0), Uint256(100000 * base, 0));  // 100,000

    IJediRouter.set_reserves(router_address, USDT, USDC, Uint256(80000 * base, 0), Uint256(80000 * small_base, 0));  // 80,000
    IJediRouter.set_reserves(router_address, USDT, DAI, Uint256(90000 * base, 0), Uint256(90000 * base, 0));  // 90,000

    IJediRouter.set_reserves(router_address, USDC, DAI, Uint256(80000 * small_base, 0), Uint256(80000 * base, 0));  // 80,000

    IJediRouter.set_reserves(router_address, shitcoin2, DAI, Uint256(10000 * base, 0), Uint256(100000 * base, 0));  // 100,000
    IJediRouter.set_reserves(router_address, shitcoin2, USDT, Uint256(1000 * base, 0), Uint256(10000 * base, 0));  // 10,000

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
