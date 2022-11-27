from starknet_py.net.account.account_client import (AccountClient)
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.contract import Contract
from starknet_py.net.models import StarknetChainId
from starkware.crypto.signature.signature import private_to_stark_key
from starknet_py.net.gateway_client import GatewayClient
from utils import deployContract
import asyncio
from pathlib import Path

ethAddress = int("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",16)
daiAddress = int("0x03e85bfbb8e2a42b7bead9e88e9a1b19dbccf661471061807292120462396ec9",16)
usdcAddress = int("0x005a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426",16)
ETH_USD_Key = 19514442401534788
DAI_USD_Key = 19212080998863684
USDC_USD_Key = 6148332971638477636
EMPIRIC_ORACLE_ADDRESS = int("0x446812bac98c08190dee8967180f4e3cdcd1db9373ca269904acb17f67f7093",16)
JediSwapRouter = int("0x012b063b60553c91ed237d8905dff412fba830c5716b17821063176c6c073341",16)
SithSwapRouter = int("0x015b7bac6b05fcb24f33011fefb592bf0579dae1d1f2a7d6645dda49849ece4d",16)
TenKRouter = int("0x00975910cd99bc56bd289eaaa5cee6cd557f0ddafdb2ce6ebea15b158eb2c664",16)
StarkSwapFactory = 0 #0x
AlphaRouter = int("0x04aec73f0611a9be0524e7ef21ab1679bdf9c97dc7d72614f15373d431226b6a",16)
execution_contract_hash = int("0x679c88ea66a1865cb1bb4afd75a6c704b925cb0b4e1d4e9e98de60ae319f93c",16)
router_aggregator_contract_hash = int("0x7fcaea53562b0f4dedd5240d6dbe82072d4611c2e45cdd0bde9e7ea386190fd",16)

#Setup Admin Account
private_key = int(Path("./.secret").read_text("utf-8"))
account_address = int("0x0000e6624768FB9550B82f667B8E3F7DB4A1E9548F173cDF1c9131497430EB7f",16)
public_key = private_to_stark_key(private_key)
signer_key_pair = KeyPair(private_key,public_key)
client = AccountClient(address=account_address, client=GatewayClient(net="testnet"), key_pair=signer_key_pair, chain=StarknetChainId.TESTNET, supported_tx_version=1)

router_aggregator_abi = [
    {
        "inputs": [
            {"name": "_token", "type": "felt"},
            {"name": "_key", "type": "felt"},
            {"name": "_oracle_address", "type": "felt"},
        ],
        "name": "set_global_price",
        "outputs": [],
        "type": "function",
    },
    {
        "inputs": [
            {"name": "_router_address", "type": "felt"},
            {"name": "_router_type", "type": "felt"},
        ],
        "name": "add_router",
        "outputs": [],
        "type": "function",
    }
]

contractAddresses = {
                    "hub": int("0x65410a254f4b7fca524d9bd8f5bccb9a750ab9b385852049e73ca1cf6b1d9d8",16),
                    "solver_registry": int("0xb01a21e9fd60a47eb24581074b7d3ded7655f919090f86dba62c2c9ac52d57",16),
                    "router_aggregator": int("0x1055d61aaea11dd4b0e6d43c3488bec11858573d6aa5eea3fd1a076a0f4913f",16),
                    "single_swap_solver": int("0x64b45c86de1b6593d0758764d35a1171a73ec2c33de4bfb98327b4f0f166909",16),
                    "spf_solver": int("0x322a1f79faab8a3857147662dbe8c60b2d8a6a087079cdaf35f6cc6ae93c79f",16),
                    "heuristic_splitter": int("0x4e1304fad2fd1ecbb5764225a6be6a1b645402da2fee499c0e3aaf6881cc9f6",16)
                    }
                    
#######################
#                     #
#   DEPLOY CONTRACTS  #
#                     #
#######################

async def deployContracts():

    if contractAddresses["hub"] == 0 :

        print("---------------------------------")
        print("--- Deploying Entire Protocol ---")
        print("---------------------------------")
        print(".")
        print(".")
        print(".")

        # Declare EVM Contract
        print("⏳ Declaring Executor Contract... ")
        declare_transaction = await client.sign_declare_transaction(
            compiled_contract=Path("./build/", "trade-executor.json").read_text("utf-8"), max_fee=int(1e16)
        )
        resp = await client.declare(transaction=declare_transaction)
        await client.wait_for_tx(resp.transaction_hash)
        execution_contract_hash = resp.class_hash
        print("Executor Class Hash: ", hex(execution_contract_hash))


        # Deploy Hub
        print("Deploying Hub")
        compiled_contract = Path("./build/", "hub.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address])
        print("Hub Address: ",contract_address)
        contractAddresses["hub"] = int(contract_address,16)

        # Deploy Solver Registry
        print("Deploying Solver Registry")
        compiled_contract = Path("./build/", "solver-registry.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address])
        print("Solver Registry Address: ",contract_address)
        contractAddresses["solver_registry"] = int(contract_address,16)

        # Deploy Router Aggregator
        print("Deploying Router Aggregator")
        compiled_contract = Path("./build/", "router-aggregator-proxy.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[router_aggregator_contract_hash,account_address,account_address])
        print("Router Aggregator Address: ",contract_address)
        contractAddresses["router_aggregator"] = int(contract_address,16)

        # Deploy Single Swap Solver
        print("Deploying Single Swap Solver")
        compiled_contract = Path("./build/", "single-swap-solver.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[contractAddresses["router_aggregator"]])
        print("Single Swap Solver Address: ",contract_address)
        contractAddresses["sigle_swap_solver"] = int(contract_address,16)

        # Deploy SPF Solver
        print("Deploying SPF Solver")
        compiled_contract = Path("./build/", "spf-solver.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address,contractAddresses["router_aggregator"]])
        print("SPF Solver Address: ",contract_address)
        contractAddresses["spf_solver"] = int(contract_address,16)

        # Deploy Heuristic Splitter Solver
        print("Deploying Heuristic Splitter Solver")
        compiled_contract = Path("./build/", "heuristic-splitter.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[contractAddresses["router_aggregator"],execution_contract_hash,contractAddresses["hub"]])
        print("Heuristic Splitter Address: ",contract_address)
        contractAddresses["heuristic_splitter"] = int(contract_address,16)
    
    ##########################
    #                        #
    #   CONFIGURE CONTRACTS  #
    #                        #
    ##########################   

    hubContract = await Contract.from_address(address=contractAddresses["hub"],client=client)
    routerAggregatorContract = Contract(address=contractAddresses["router_aggregator"], abi=router_aggregator_abi, client=client)
    solverRegistryContract = await Contract.from_address(contractAddresses["solver_registry"],client)
    singleSwapSolverContract = await Contract.from_address(contractAddresses["single_swap_solver"],client)
    spfSolverContract = await Contract.from_address(contractAddresses["spf_solver"],client)
    heurtisticSplitterContract = await Contract.from_address(contractAddresses["heuristic_splitter"],client)

    #Configure Hub
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

