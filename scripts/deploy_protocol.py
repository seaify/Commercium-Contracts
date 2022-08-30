from starknet_py.net import AccountClient
from starknet_py.net.client import Client
from starknet_py.net.signer.stark_curve_signer import (StarkCurveSigner,KeyPair)
from starknet_py.contract import Contract
from starknet_py.net.networks import TESTNET
from starknet_py.net.models import StarknetChainId
from starkware.crypto.signature.signature import (pedersen_hash, private_to_stark_key, sign)
import asyncio
from pathlib import Path

ethAddress = 2087021424722619777119509474943472645767659996348769578120564519014510906823
daiAddress = 1767481910113252210994791615708990276342505294349567333924577048691453030089
ETH_USD_Key = 28556963469423460
DAI_USD_Key = 28254602066752356
EMPIRIC_ORACLE_ADDRESS = 536554312408700354284283040928046824434969893969739486945260186308733942996
JediSwapRouter = 528330283628715324117473561763116327110398297690851013171802704612289884993
execution_contract_hash = 2064099869494044600463193389870658049751373975999385172371135047097091846831

#Setup Admin Account
private_key = 514919074163669761001641341781643512607564785866885624866019752723630562244
account_address = 1590051254895316108224788633147187307512845622787220809042235657274059647
public_key = private_to_stark_key(private_key)
client = AccountClient(net="testnet", chain=StarknetChainId.TESTNET,n_retries=1,address=account_address,key_pair=KeyPair(private_key,public_key))

hubABI = Path("./build/", "hub_abi.json").read_text("utf-8")

contractAddresses = {"hub": 2564871805806106849975133249130922009633518990198014318443179860106012529501,
                    "solver_registry": 339234692535171577551477557872295479580825059112759814425791895611285703998,
                    "router_aggregator": 141598234779943145909949961255707921073346208612990875967745473717510442335,
                    "single_swap_solver": 3129224635722298990038073977040022864604796615622257110045829298235759774007,
                    "spf_solver": 2671560820787853880739211732065112677201613849594734093942110582342388784590}
                    
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
        compiled = Path("./build/", "router_aggregator_testnet.json").read_text("utf-8")
        deployment_result = await Contract.deploy(
            client, compiled_contract=compiled, constructor_args=[account_address]
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
    
    ##########################
    #                        #
    #   CONFIGURE CONTRACTS  #
    #                        #
    ##########################   

    hubContract = await Contract.from_address(contractAddresses["hub"],client)
    routerAggregatorContract = await Contract.from_address(contractAddresses["router_aggregator"],client)
    solverRegistryContract = await Contract.from_address(contractAddresses["solver_registry"],client)
    singleSwapSolverContract = await Contract.from_address(contractAddresses["single_swap_solver"],client)
    spfSolverContract = await Contract.from_address(contractAddresses["spf_solver"],client)

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
    #Add Router
    print("Adding JediSwapRouter...")
    invocation = await routerAggregatorContract.functions["add_router"].invoke(JediSwapRouter,1,max_fee=50000000000000000000)
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

    #Configure Solvers
    print("...Configuring Solvers...")
    #Setting Router Aggregator
    print("Setting Router Aggregator for Single Swap Solver...")
    invocation = await singleSwapSolverContract.functions["set_router_aggregator"].invoke(routerAggregatorContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    print("Setting Router Aggregator for SPF Solver...")
    invocation = await spfSolverContract.functions["set_router_aggregator"].invoke(routerAggregatorContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    #Set high liq tokens for spf solver 

asyncio.run(deployContracts())

