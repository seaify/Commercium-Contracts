from starknet_py.net.account.account_client import AccountClient
from starknet_py.contract import Contract

#Deploy a Contract
async def deployContract(client: AccountClient,compiled_contract: str, calldata: list(str)) -> (str):
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=int(1e16)
    )
    await declare_result.wait_for_acceptance()
    print("⏳ Waiting for decleration...")

    deploy_result = await declare_result.deploy(max_fee=int(1e16), calldata=calldata)
    await deploy_result.wait_for_acceptance()
    print("⏳ Waiting for deployment...")
    contract = deploy_result.deployed_contract
    return contract.address