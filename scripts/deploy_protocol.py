rom starknet_py.net.gateway_client import GatewayClient
from starknet_py.contract import Contract
from starknet_py.net.networks import TESTNET

client = GatewayClient(TESTNET)

# Use list for positional arguments
constructor_args = [123]

# or use dict for keyword arguments
constructor_args = {"_public_key": 123}

# contract as a string
deployment_result = await Contract.deploy(
    client, compilation_source=contract, constructor_args=constructor_args
)

# list with filepaths - useful for multiple files
deployment_result = await Contract.deploy(
    client,
    compilation_source=[directory_with_contracts / "contract.cairo"],
    constructor_args=constructor_args,
)

# or use already compiled program
compiled = (directory_with_contracts / "contract_compiled.json").read_text("utf-8")
deployment_result = await Contract.deploy(
    client, compiled_contract=compiled, constructor_args=constructor_args
)

# you can wait for transaction to be accepted
await deployment_result.wait_for_acceptance()

# but you can access the deployed contract object even if has not been accepted yet
contract = deployment_result.deployed_contract