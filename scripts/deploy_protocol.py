from starknet_py.net.account.account_client import (AccountClient)
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.contract import Contract
from starknet_py.net.models import StarknetChainId
from starkware.crypto.signature.signature import private_to_stark_key
from starknet_py.net.gateway_client import GatewayClient
import asyncio
from pathlib import Path

ethAddress = 2087021424722619777119509474943472645767659996348769578120564519014510906823
daiAddress = 1767481910113252210994791615708990276342505294349567333924577048691453030089
usdcAddress = 159707947995249021625440365289670166666892266109381225273086299925265990694
ETH_USD_Key = 28556963469423460
DAI_USD_Key = 28254602066752356
USDC_USD_Key = 8463218501920060260
EMPIRIC_ORACLE_ADDRESS = 536554312408700354284283040928046824434969893969739486945260186308733942996
JediSwapRouter = 528330283628715324117473561763116327110398297690851013171802704612289884993
SithSwapRouter = 613949494660459508506795653074444441520878567657307565614735576897368804941
TenKRouter = 267408615217810058547382786818850841436210122758739315180755587026551752292 
execution_contract_hash = 2032713593507808284182517340973952218645684941574514214579184653429499031220 #0x047e79a1a2e15757b01133b9d398b2ffe701f38b0d6efc43179aafcf3ac4eeb4
router_aggregator_contract_hash = 2142082874301946878448248470368908189433629508984675061261861742626779907 #0x0001365e450cca9282818dfbcec722141177b2d230687ef073717eef703cb303

#Setup Admin Account
private_key = 514919074163669761001641341781643512607564785866885624866019752723630562244
account_address = 1590051254895316108224788633147187307512845622787220809042235657274059647
public_key = private_to_stark_key(private_key)
client = AccountClient(address=public_key, client=GatewayClient(net="testnet"), key_pair=public_key, chain=StarknetChainId.TESTNET)

hubABI = Path("./build/", "hub_abi.json").read_text("utf-8")

contractAddresses = {
                    "hub": 195676955388641969910971142725788696336641048491385389846694951076261197764, #0x006ebfcdaa2d47342f321249a0024e1f778894a05b8bed8393ba60d6f36af7c4
                    "solver_registry": 1158496595100949956285385094834746919293397342197235621735292995323969857338, #0x028faf92f6035c779291d3815ea1e5736ad8f9023c5ef0138bed11c1534ee73a
                    "router_aggregator": 1382653231822326866149049255933993724241685476625671975132788115005722069472, #0x030e8dd2b7a9a24cdb0a28d59ee51211e24453599b3021a97c591095a82809e0
                    "single_swap_solver": 964741909191253954736952351625934561864974584204796917548090532924918607817, #0x0222064a3be631f4fc4ec5fe713781f22a3c713f6ceea26d82ef8fe76f702fc9
                    "spf_solver": 2765128285648798492957389366043110318914294898428315636852557766765085513755, #0x061d01d4721846045efd7eb2ad5020034cfce683d9c12a6688f538f295c0d81b
                    "heuristic_splitter": 623197502784579584450398684832949545841380877718155062741899362229954450451 #0x0160b7a01aade703fb09eb7073316bc15aa1871afbe45fc5c3a0ec36bb0a9413
                    }
                    
#######################
#                     #
#   DEPLOY CONTRACTS  #
#                     #
#######################

async def deployContracts():

    if contractAddresses["hub"] == 0 :
        # Deploy Hub
        print("Deploying Hub")
        compiled = Path("./build/", "hub.json").read_text("utf-8")
        deployment_result = await Contract.deploy(
            client, compiled_contract=compiled, constructor_args=[account_address]
        )
        print("Waiting for acceptance...")
        await deployment_result.wait_for_acceptance()
        contract = deployment_result.deployed_contract
        print("Hub Address: ",contract.address)
        contractAddresses["hub"] = contract.address

        # Deploy Solver Registry
        print("Deploying Solver Registry")
        compiled = Path("./build/", "solver_registry.json").read_text("utf-8")
        deployment_result = await Contract.deploy(
            client, compiled_contract=compiled, constructor_args=[account_address]
        )
        print("Waiting for acceptance...")
        await deployment_result.wait_for_acceptance()
        contract = deployment_result.deployed_contract
        print("Solver Registry Address: ",contract.address)
        contractAddresses["solver_registry"] = contract.address

        # Deploy Router Aggregator
        print("Deploying Router Aggregator")
        compiled = Path("./build/", "router_aggregator_proxy.json").read_text("utf-8")
        deployment_result = await Contract.deploy(
            client, compiled_contract=compiled, constructor_args=[router_aggregator_contract_hash,account_address,account_address]
        )
        print("Waiting for acceptance...")
        await deployment_result.wait_for_acceptance()
        contract = deployment_result.deployed_contract
        print("Router Aggregator Address: ",contract.address)
        contractAddresses["router_aggregator"] = contract.address 

        # Deploy Single Swap Solver
        print("Deploying Single Swap Solver")
        compiled = Path("./build/", "single_swap_solver.json").read_text("utf-8")
        deployment_result = await Contract.deploy(
            client, compiled_contract=compiled, constructor_args=[]
        )
        print("Waiting for acceptance...")
        await deployment_result.wait_for_acceptance()
        contract = deployment_result.deployed_contract
        print("Single Swap Solver Address: ",contract.address)
        contractAddresses["sigle_swap_solver"] = contract.address

        # Deploy SPF Solver
        print("Deploying SPF Solver")
        compiled = Path("./build/", "spf_solver.json").read_text("utf-8")
        deployment_result = await Contract.deploy(
            client, compiled_contract=compiled, constructor_args=[account_address]
        )
        print("Waiting for acceptance...")
        await deployment_result.wait_for_acceptance()
        contract = deployment_result.deployed_contract
        print("SPF Solver Address: ",contract.address)
        contractAddresses["spf_solver"] = contract.address

        # Deploy Heuristic Splitter Solver
        print("Deploying Heuristic Splitter Solver")
        compiled = Path("./build/", "heuristic_splitter.json").read_text("utf-8")
        deployment_result = await Contract.deploy(
            client, compiled_contract=compiled, constructor_args=[account_address]
        )
        print("Waiting for acceptance...")
        await deployment_result.wait_for_acceptance()
        contract = deployment_result.deployed_contract
        print("Heuristic Splitter Address: ",contract.address)
        contractAddresses["heuristic_splitter"] = contract.address
    
    ##########################
    #                        #
    #   CONFIGURE CONTRACTS  #
    #                        #
    ##########################   

    hubContract = await Contract.from_address(address=contractAddresses["hub"],client=client)
    routerAggregatorContract = await Contract.from_address(contractAddresses["router_aggregator"],client)
    solverRegistryContract = await Contract.from_address(contractAddresses["solver_registry"],client)
    singleSwapSolverContract = await Contract.from_address(contractAddresses["single_swap_solver"],client)
    spfSolverContract = await Contract.from_address(contractAddresses["spf_solver"],client)
    heurtisticSplitterContract = await Contract.from_address(contractAddresses["heuristic_splitter"],client)

    # Configure Hub
    print("...Configuring Hub...")
    #Set Solver Registry
    invocation = await hubContract.functions["set_solver_registry"].invoke(solverRegistryContract.address,max_fee=50000000000000000000)
    print("Setting Solver Registry...")
    await invocation.wait_for_acceptance()
    #Set Trade Executioner
    print("Setting TradeExecutioner Hash...")
    invocation = await hubContract.functions["set_executor"].invoke(execution_contract_hash,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

    #Configure Router Aggregator
    print("...Configuring Router Aggregator...")
    #Set Price Feeds
    print("Adding ETH Price Feed...")
    invocation = await routerAggregatorContract.functions["set_global_price"].invoke(ethAddress,ETH_USD_Key,EMPIRIC_ORACLE_ADDRESS,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    print("Adding DAI Price Feed...")
    invocation = await routerAggregatorContract.functions["set_global_price"].invoke(daiAddress,DAI_USD_Key,EMPIRIC_ORACLE_ADDRESS,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    print("Adding USDC Price Feed...")
    invocation = await routerAggregatorContract.functions["set_global_price"].invoke(usdcAddress,USDC_USD_Key,EMPIRIC_ORACLE_ADDRESS,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    #Add Routers
    print("Adding JediSwapRouter...")
    invocation = await routerAggregatorContract.functions["add_router"].invoke(JediSwapRouter,0,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    print("Adding SithSwapRouter...")
    invocation = await routerAggregatorContract.functions["add_router"].invoke(SithSwapRouter,2,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    print("Adding TenKRouter...")
    invocation = await routerAggregatorContract.functions["add_router"].invoke(TenKRouter,3,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()    

    #Configure Solver Registry
    print("...Configuring Solver Registry...")
    #Add Single Swap Solver to Registry
    print("Adding Single Swap Solver...")
    invocation = await solverRegistryContract.functions["set_solver"].invoke(1,singleSwapSolverContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance() 
    print("Adding SPF Solver...")
    invocation = await solverRegistryContract.functions["set_solver"].invoke(2,spfSolverContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance() 
    print("Adding Heuristic Splitter Solver...")
    invocation = await solverRegistryContract.functions["set_solver"].invoke(3,heurtisticSplitterContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

    #Configure Solvers
    print("...Configuring Solvers...")
    #Setting Router Aggregator
    print("Setting Router Aggregator for Single Swap Solver...")
    invocation = await singleSwapSolverContract.functions["set_router_aggregator"].invoke(routerAggregatorContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    print("Setting Router Aggregator for SPF Solver...")
    invocation = await spfSolverContract.functions["set_router_aggregator"].invoke(routerAggregatorContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    print("Setting Router Aggregator for Heuristic Splitter Solver...")
    invocation = await heurtisticSplitterContract.functions["set_router_aggregator"].invoke(routerAggregatorContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    #Set high liq tokens for spf solver
    print("Setting High liq tokens for SPF Solver...")
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("0",ethAddress,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("1",daiAddress,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("2",usdcAddress,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

asyncio.run(deployContracts())

