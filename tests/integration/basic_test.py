from starknet_py.contract import Contract
from deploy_contracts import deployContracts
import asyncio
from protocol_interactions import swap_with_solver
from global_info import (
    client,  
    ETH_Contract,
    DAI_Contract,
    USDC_Contract,
    account_address
)

#############################
#                           #
#     Integration Tests     #
#                           #
#############################

async def test_full_protocol():
    protocol_contracts = await deployContracts()
    await solvers_test(protocol_contracts,[2])

async def solvers_test(protocol_contracts: dict[str,int], IDs: list[int]):
    print("Testing Solvers...")
    Hub_Contract = protocol_contracts["hub"]
    #1, 1e9, 1e18
    eth_to_spend = [1000000000, 1000000000000000000]
    print("ETH - DAI Swaps:")
    await swap_with_solver(ETH_Contract,DAI_Contract,Hub_Contract,eth_to_spend,IDs,account_address)
    
    #1e9, 1e18
    eth_to_spend = [1000000000, 1000000000000000000]
    print("ETH - USDC Swaps:")
    await swap_with_solver(ETH_Contract,USDC_Contract,Hub_Contract,eth_to_spend,IDs,account_address)
    
    #1
    usdc_to_spend = [1000000]
    print("USDC - ETH Swaps:")
    await swap_with_solver(USDC_Contract,ETH_Contract,Hub_Contract,usdc_to_spend,IDs,account_address)

async def hub_functions():
    return

asyncio.run(test_full_protocol())