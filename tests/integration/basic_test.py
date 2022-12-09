from starknet_py.contract import Contract
from .deploy_contracts import deployContracts
import asyncio
from .global_info import (
    client,  
    ETH_Contract,
    DAI_Contract,
    USDC_Contract
)

#############################
#                           #
#     Integration Tests     #
#                           #
#############################

async def fullTestSuite():
    protocol_contracts = await deployContracts()
    await testSolvers(protocol_contracts)

async def testSolvers(protocol_contracts: dict[str,int]):

    print("Testing Solvers...")
    Hub_Contract = protocol_contracts["hub"]

    print("Hub Address: ", Hub_Contract.address)
    print("ETH Address: ", ETH_Contract.address)
    print("DAI Address: ", DAI_Contract.address)
    
    #(res,) = await hubContract.functions["solver_registry"].call()
    #print("Getting Amount out...")
    #(res,) = await hubContract.functions["get_amount_out"].call({"low": 1000000, "high":0},ethAddress,daiAddress)
    
    print("Approving trade...")
    invocation = await ETH_Contract.functions["approve"].invoke(Hub_Contract.address,{"low": 1000000, "high":0},max_fee=50000000000000000000)
    print("Waiting for acceptance...")
    await invocation.wait_for_acceptance()
    
    #print("Approving trade...")
    #invocation = await erc20Contract.functions["approve"].invoke(hubContract.address,{"low": 1000000, "high":0},max_fee=50000000000000000000)
    #print("Waiting for acceptance...")
    #await invocation.wait_for_acceptance()
    #print("Approving trade...")
    #invocation = await erc20Contract.functions["approve"].invoke(hubContract.address,{"low": 1000000, "high":0},max_fee=50000000000000000000)
    #print("Waiting for acceptance...")
    #await invocation.wait_for_acceptance()
    #print("Setting Registry...")
    #invocation = await hubContract.functions["set_solver_registry"].invoke(account_address,max_fee=50000000000000000000)
    #await invocation.wait_for_acceptance()
    
    
    #print("Performing trade...")
    #invocation = await hubContract.functions["swap_exact_tokens_for_tokens"].invoke({"low": 1000000, "high":0},{"low": 0, "high":0},ethAddress,daiAddress,account_address,max_fee=50000000000000000000)
    #print("Waiting for acceptance...")
    #await invocation.wait_for_acceptance()

asyncio.run(fullTestSuite())


