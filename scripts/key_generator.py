from starknet_py.contract import ContractFunction
from starkware.crypto.signature.signature import (pedersen_hash, private_to_stark_key, sign)

private_key = int("05867ebc9d1848c207d95472ae00faebf94e222ef52613498bbd9bc04b3ef626",16)
public_key = private_to_stark_key(private_key)
print("public key: ",public_key)
