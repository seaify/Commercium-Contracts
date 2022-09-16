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
execution_contract_hash = 242426945107153255960771867351046272004977902559623537068912744283860039850
router_aggregator_contract_hash = 128366282019189000959900597506044096446998519897774588451956949944576865420

#Setup Admin Account
private_key = 514919074163669761001641341781643512607564785866885624866019752723630562244
account_address = 1590051254895316108224788633147187307512845622787220809042235657274059647
public_key = private_to_stark_key(private_key)
client = AccountClient(address=public_key, client=GatewayClient(net="testnet"), key_pair=public_key, chain=StarknetChainId.TESTNET)

hubABI = Path("./build/", "hub_abi.json").read_text("utf-8")

contractAddresses = {"hub": 1239839734979793769720295449576425419964934840817251849524590085431968166742,
                    "solver_registry": 1882006508965251690485885641123166906116041092081954896070954408113553152764,
                    "router_aggregator": 2448590369462025244879222903441322187593123184637584223065955163372978154113,
                    "single_swap_solver": 3570901364099080073297797560913839000276060763254904810760667781305201703685,
                    "spf_solver": 1669938796048367595768211772001259401475560614108645121815530432075956769035,
                    "heuristic_splitter": 2157289568508390495651273650241984071263271030297552139724246128684486012095}
                    
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

