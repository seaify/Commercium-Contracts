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
ETH_USD_Key = 19514442401534788
DAI_USD_Key = 28254602066752356
USDC_USD_Key = 8463218501920060260
EMPIRIC_ORACLE_ADDRESS = int("0x446812bac98c08190dee8967180f4e3cdcd1db9373ca269904acb17f67f7093",16)
JediSwapRouter = int("0x012b063b60553c91ed237d8905dff412fba830c5716b17821063176c6c073341",16)
SithSwapRouter = int("0x015b7bac6b05fcb24f33011fefb592bf0579dae1d1f2a7d6645dda49849ece4d",16)
TenKRouter = int("0x00975910cd99bc56bd289eaaa5cee6cd557f0ddafdb2ce6ebea15b158eb2c664",16)
StarkSwapFactory = 0 #0x
AlphaRouter = int("0x04aec73f0611a9be0524e7ef21ab1679bdf9c97dc7d72614f15373d431226b6a",16)
execution_contract_hash = int("0x03d451a4e2c1eb46424daed0d51d066c7c6b4360ee3e9fe6242884b50b628f32",16)
router_aggregator_contract_hash = int("0x029facf61d340fa7ae41dc4512fc9d211616a441d42ebe5b0ef0fa4c32197143",16)

#Setup Admin Account
private_key = Path("./.secret")
account_address = int("0x0000e6624768FB9550B82f667B8E3F7DB4A1E9548F173cDF1c9131497430EB7f",16)
public_key = private_to_stark_key(private_key)
client = AccountClient(address=public_key, client=GatewayClient(net="testnet"), key_pair=public_key, chain=StarknetChainId.TESTNET)

hubABI = Path("./build/", "hub_abi.json").read_text("utf-8")

contractAddresses = {
                    "hub": int("0x017ab62c44865039b22ea344b2a6c449838f3c735d627f5ba9f6fc824120269f",16),
                    "solver_registry": int("0x04f1c8c1686ae5407c871753082e6dc9a2586a6d585bfc757db0481fb0f3a1f3",16),
                    "router_aggregator": int("0x022bc8ab391f4f31e1a67506fd279272da0fd13041dea9ca98414f6719eaff37",16),
                    "single_swap_solver": int("0x0127c973e386aa39098a14925d41ff7e2ba98aa098e2bb13604c83cd92e2c17f",16),
                    "spf_solver": int("0x05be7131d2131b7d1e79c200c6fc3957338588a3e2a5dac08f62ac1de2c39f6f",16),
                    "heuristic_splitter": int("0x000da18653c320d0fd70224efd3353caa36f645890b3a896f310269ff90bfda4",16)
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
            client, compiled_contract=compiled, constructor_args=[contractAddresses["router_aggregator"]]
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
            client, compiled_contract=compiled, constructor_args=[account_address,contractAddresses["router_aggregator"]]
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
            client, compiled_contract=compiled, constructor_args=[contractAddresses["router_aggregator"]]
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
    print("Adding AlphaRouter...")
    invocation = await routerAggregatorContract.functions["add_router"].invoke(AlphaRouter,1,max_fee=50000000000000000000)
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
    #Set high liq tokens for spf solver
    print("Setting High liq tokens for SPF Solver...")
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("0",ethAddress,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("1",daiAddress,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("2",usdcAddress,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

asyncio.run(deployContracts())

