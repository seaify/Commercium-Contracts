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
execution_contract_hash = 1303868135432211508377640524314631384852978687846524669563657157299993080336 #0x02e1f6951388b93ea1d0d03272b1990253b5b69f8257cb120eab7d0708b07210
router_aggregator_contract_hash = 810491866414080855657092578804741905652974177451333088272418463240559289655 #0x01cab8de28ec15ac1633507516a1e1bae7903fdfb8fcc4746d613fa96b586537

#Setup Admin Account
private_key = 514919074163669761001641341781643512607564785866885624866019752723630562244
account_address = 1590051254895316108224788633147187307512845622787220809042235657274059647
public_key = private_to_stark_key(private_key)
client = AccountClient(address=public_key, client=GatewayClient(net="testnet"), key_pair=public_key, chain=StarknetChainId.TESTNET)

hubABI = Path("./build/", "hub_abi.json").read_text("utf-8")

contractAddresses = {"hub": 2862851884670337791468481853350094996009273925859464654276805337452775159429,
                    "solver_registry": 1485972785969550055947104761688560649707878844040762012866812566881990441165,
                    "router_aggregator": 1754063576939863416427042396748744572379775889970003569618112568568629372733,
                    "single_swap_solver": 1210000264506396724228163300962368934318656384334573574868366997891674598777,
                    "spf_solver": 3116087909705702218029411134867896963171052237072903650533868153212282454224,
                    "heuristic_splitter": 930155564200660671732096556634681016799250751849225517239647528948190248031}
                    
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
    #Add Router
    print("Adding JediSwapRouter...")
    invocation = await routerAggregatorContract.functions["add_router"].invoke(JediSwapRouter,0,max_fee=50000000000000000000)
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

