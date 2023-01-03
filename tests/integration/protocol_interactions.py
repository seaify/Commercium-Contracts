from starknet_py.contract import Contract

async def swap_with_solver(
    In_Token_Contract: Contract, 
    Out_Token_Contract: Contract, 
    Hub_Contract: Contract,
    amounts_to_spend: list,
    solvers_to_use: list,
    sender_address: str
    ):

    for spend_amount in amounts_to_spend:
        for solver_id in solvers_to_use:
            
            #Approve token transfer
            invocation = await In_Token_Contract.functions["approve"].invoke(Hub_Contract.address,{"low": spend_amount, "high":0},max_fee=50000000000000000000)
            await invocation.wait_for_acceptance()

            (previous_dai_balance,) = await Out_Token_Contract.functions["balanceOf"].call(sender_address)
            (previous_eth_balance,) = await In_Token_Contract.functions["balanceOf"].call(sender_address)

            #Getting the solver estimated amount
            (received_dai_amount,) = await Hub_Contract.functions["get_amount_out_with_solver"].call({"low": spend_amount, "high":0},In_Token_Contract.address,Out_Token_Contract.address,solver_id)

            #Executing the swap
            invocation = await Hub_Contract.functions["swap_exact_tokens_for_tokens_with_solver"].invoke({"low": spend_amount, "high":0},{"low": 0, "high":0},In_Token_Contract.address,Out_Token_Contract.address,sender_address,solver_id,max_fee=50000000000000000000)
            await invocation.wait_for_acceptance()

            #Get new Balance
            (new_dai_balance,) = await Out_Token_Contract.functions["balanceOf"].call(sender_address)
            (new_eth_balance,) = await In_Token_Contract.functions["balanceOf"].call(sender_address)

            print("previous_dai_balance: ",previous_dai_balance)
            print("received_dai_amount: ",received_dai_amount)
            print("new_dai_balance: ",new_dai_balance)

            #Make sure new balance are correct
            assert new_dai_balance == previous_dai_balance + received_dai_amount, f"actual DAI balance: {new_dai_balance} expected DAI balance: {previous_dai_balance + received_dai_amount}"
            assert new_eth_balance == previous_eth_balance - spend_amount, f"actual ETH balance: {new_eth_balance} expected ETH balance: {previous_eth_balance + spend_amount}"

            print("✅")