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
JediSwapRouter = 528330283628715324117473561763116327110398297690851013171802704612289884993 #0x012b063b60553c91ed237d8905dff412fba830c5716b17821063176c6c073341
SithSwapRouter = 613949494660459508506795653074444441520878567657307565614735576897368804941 #0x015b7bac6b05fcb24f33011fefb592bf0579dae1d1f2a7d6645dda49849ece4d
TenKRouter = 267408615217810058547382786818850841436210122758739315180755587026551752292 #0x00975910cd99bc56bd289eaaa5cee6cd557f0ddafdb2ce6ebea15b158eb2c664
StarkSwapFactory = 0 #0x
AlphaRouter = 2118057930243295689209699260109286459508439101415299206807991604654635117418 #0x04aec73f0611a9be0524e7ef21ab1679bdf9c97dc7d72614f15373d431226b6a
execution_contract_hash = 1732073610248511674811290648671968077467369994580880265034892474171516948274 #0x03d451a4e2c1eb46424daed0d51d066c7c6b4360ee3e9fe6242884b50b628f32
router_aggregator_contract_hash = 1493724358487246524740862515688018880561932060018213207540353152755385899269 #0x034d6b03c781dacec6b96d3f4b4749d48b57b6743fed67236f7037e1b78a1905

#Setup Admin Account
private_key = 514919074163669761001641341781643512607564785866885624866019752723630562244
account_address = 1590051254895316108224788633147187307512845622787220809042235657274059647
public_key = private_to_stark_key(private_key)
client = AccountClient(address=public_key, client=GatewayClient(net="testnet"), key_pair=public_key, chain=StarknetChainId.TESTNET)

hubABI = Path("./build/", "hub_abi.json").read_text("utf-8")

contractAddresses = {
                    "hub": 274692304459003283793059090670630100894454073216364957955103066536672045174, #0x009b7867da3ab62a5fc5720e05dc8f65ce11023e2b80a4d40df05407acbd2876
                    "solver_registry": 1739533146778955178914359505356608475491000623024368656149497309490122490040, #0x03d88a76793bfa98ae8b2aa20ead91c724640b3d1668e8c5eba69982856280b8
                    "router_aggregator": 2735043677472181060562604494041866139075777317052714635582567658651033845047, #0x060bfad84f0c925dcbe2f6cb0f9cc8b9f4c2aee5e6c7848ee0e8218446c4bd37
                    "single_swap_solver": 1010565484178145392627352663020261903255420392590902869754524420180555497354, #0x023bf5b5188a4610be88c293315bd2c092ce00e671dc9c410fe7e25ddeb67f8a
                    "spf_solver": 1839651039311515750393348194795615040334675018164158440929873934945956386101, #0x041134a180570508050520524d7f2e76056d0f6feca8507240d593a18d6bd535
                    "heuristic_splitter": 1633056736795720238243193650918956488659335775891031465579536540405582730030, #0x039c4700ece9c6d56d50fdcf49c7c6119f8c6dbac92393ab3a221a94a933132e
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

