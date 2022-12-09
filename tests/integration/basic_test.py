from starknet_py.contract import Contract
from deploy_contracts import deployContracts
import asyncio
import pytest
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
    await solvers_test(protocol_contracts,[1,2,3])

async def solvers_test(protocol_contracts: dict[str,int], IDs: list[int]):

    print("Testing Solvers...")
    Hub_Contract = protocol_contracts["hub"]
    eth_to_spend = 1000000000000

    for id in IDs:
        print("Solver ID: ", id)
        
        #Approve token transfer
        invocation = await ETH_Contract.functions["approve"].invoke(Hub_Contract.address,{"low": eth_to_spend, "high":0},max_fee=50000000000000000000)
        await invocation.wait_for_acceptance()

        (previous_dai_balance,) = await DAI_Contract.functions["balanceOf"].call(account_address)
        (previous_eth_balance,) = await ETH_Contract.functions["balanceOf"].call(account_address)

        #Getting the solver estimated amount
        (received_dai_amount,) = await Hub_Contract.functions["get_amount_out_with_solver"].call({"low": eth_to_spend, "high":0},ETH_Contract.address,DAI_Contract.address,id)
        
        #Executing the swap
        invocation = await Hub_Contract.functions["swap_exact_tokens_for_tokens"].invoke({"low": eth_to_spend, "high":0},{"low": 0, "high":0},ETH_Contract.address,DAI_Contract.address,account_address,max_fee=50000000000000000000)
        await invocation.wait_for_acceptance()

        #Get new Balance
        (new_dai_balance,) = await DAI_Contract.functions["balanceOf"].call(account_address)
        (new_eth_balance,) = await ETH_Contract.functions["balanceOf"].call(account_address)

        #Make sure new balance are correct
        assert new_dai_balance == previous_dai_balance + received_dai_amount, f"actual DAI balance: {new_dai_balance} expected DAI balance: {previous_dai_balance + received_dai_amount}"
        assert new_eth_balance == previous_eth_balance - eth_to_spend, f"actual ETH balance: {new_eth_balance} expected ETH balance: {previous_eth_balance + eth_to_spend}"

        print("✅")


asyncio.run(test_full_protocol())