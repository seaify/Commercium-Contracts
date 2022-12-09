from starknet_py.net.account.account_client import (AccountClient)
from starknet_py.contract import Contract
from pathlib import Path

from global_info import (
    client, 
    JediSwapRouter,
    TenKRouter, 
    EMPIRIC_ORACLE_ADDRESS, 
    ETH_USD_Key, 
    DAI_USD_Key, 
    USDC_USD_Key,
    account_address,
    router_aggregator_abi,
    ETH_Contract,
    DAI_Contract,
    USDC_Contract
)

contractAddresses = {
    "hub": int("0x0",16),
    "solver_registry": int("0x0",16),
    "router_aggregator": int("0x0",16),
    "single_swap_solver": int("0x0",16),
    "spf_solver": int("0x0",16),
    "heuristic_splitter": int("0x0",16)
}


async def deployContracts():

    print("________DEPLOYING CONTRACTS___________")

    if contractAddresses["hub"] == 0 :

        # Declare Trade Executor Contract
        declare_transaction = await client.sign_declare_transaction(
            compiled_contract=Path("./build/", "trade-executor.json").read_text("utf-8"), max_fee=int(1e16)
        )
        resp = await client.declare(transaction=declare_transaction)
        await client.wait_for_tx(resp.transaction_hash)
        execution_contract_hash = resp.class_hash

        # Declare Router Aggregator Contract
        declare_transaction = await client.sign_declare_transaction(
            compiled_contract=Path("./build/", "router-aggregator.json").read_text("utf-8"), max_fee=int(1e16)
        )
        resp = await client.declare(transaction=declare_transaction)
        await client.wait_for_tx(resp.transaction_hash)
        router_aggregator_contract_hash = resp.class_hash

        # Deploy Hub
        compiled_contract = Path("./build/", "hub.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address,execution_contract_hash])
        contractAddresses["hub"] = int(contract_address,16)
        print("✅ Hub: ",contract_address)

        # Deploy Solver Registry
        compiled_contract = Path("./build/", "solver-registry.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address])
        contractAddresses["solver_registry"] = int(contract_address,16)
        print("✅ Solver Registry: ",contract_address)

        # Deploy Router Aggregator
        compiled_contract = Path("./build/", "router-aggregator-proxy.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[router_aggregator_contract_hash,account_address,account_address])
        contractAddresses["router_aggregator"] = int(contract_address,16)
        print("✅ Router Aggregator: ",contract_address)

        # Deploy Single Swap Solver
        compiled_contract = Path("./build/", "single-swap-solver.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[contractAddresses["router_aggregator"]])
        contractAddresses["single_swap_solver"] = int(contract_address,16)
        print("✅ Single Swap Solver: ",contract_address)

        # Deploy SPF Solver
        compiled_contract = Path("./build/", "spf-solver.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address,contractAddresses["router_aggregator"]])
        contractAddresses["spf_solver"] = int(contract_address,16)
        print("✅ SPF Solver: ",contract_address)

        # Deploy Heuristic Splitter Solver
        compiled_contract = Path("./build/", "heuristic-splitter.json").read_text("utf-8")
        contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[contractAddresses["router_aggregator"],int("0x4919e548bfd37db237cf4223b407e710103f79ebee92d2baa7a733d28532597",16),contractAddresses["hub"]])
        contractAddresses["heuristic_splitter"] = int(contract_address,16)
        print("✅ Heuristic Solver: ",contract_address)
    
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

    protocol_contracts = {
        "hub": hubContract,
        "solver_registry": solverRegistryContract,
        "router_aggregator": routerAggregatorContract,
        "single_swap_solver": singleSwapSolverContract,
        "spf_solver": spfSolverContract,
        "heuristic_splitter": heurtisticSplitterContract
    }

    #Configure Hub
    #Set Solver Registry
    invocation = await hubContract.functions["set_solver_registry"].invoke(solverRegistryContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

    #Configure Router Aggregator
    #Set Price Feeds
    invocation = await routerAggregatorContract.functions["set_global_price"].invoke(ETH_Contract.address,ETH_USD_Key,EMPIRIC_ORACLE_ADDRESS,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await routerAggregatorContract.functions["set_global_price"].invoke(DAI_Contract.address,DAI_USD_Key,EMPIRIC_ORACLE_ADDRESS,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await routerAggregatorContract.functions["set_global_price"].invoke(USDC_Contract.address,USDC_USD_Key,EMPIRIC_ORACLE_ADDRESS,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    #Add Routers
    invocation = await routerAggregatorContract.functions["add_router"].invoke(TenKRouter,0,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()        
    invocation = await routerAggregatorContract.functions["add_router"].invoke(JediSwapRouter,1,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

    #Configure Solver Registry
    #Add Single Swap Solver to Registry
    invocation = await solverRegistryContract.functions["set_solver"].invoke(1,singleSwapSolverContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance() 
    invocation = await solverRegistryContract.functions["set_solver"].invoke(2,spfSolverContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance() 
    invocation = await solverRegistryContract.functions["set_solver"].invoke(3,heurtisticSplitterContract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

    #Configure Solvers
    #Set high liq tokens for spf solver
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("0",ETH_Contract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("1",DAI_Contract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    invocation = await spfSolverContract.functions["set_high_liq_tokens"].invoke("2",USDC_Contract.address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()

    print("✅ Configured Contracts")

    return protocol_contracts

async def deployContract(client: AccountClient,compiled_contract: str, calldata) -> (str):
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=int(1e16)
    )
    await declare_result.wait_for_acceptance()

    deploy_result = await declare_result.deploy(max_fee=int(1e16), constructor_args=calldata)
    await deploy_result.wait_for_acceptance()
    contract = deploy_result.deployed_contract
    return hex(contract.address)