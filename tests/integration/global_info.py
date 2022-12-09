from starknet_py.net.account.account_client import (AccountClient)
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.net.models import StarknetChainId
from starkware.crypto.signature.signature import private_to_stark_key
from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
import json
from pathlib import Path

#######################
#                     #
#     Global Info     #
#                     #
#######################

#devnet-seed = 2492750914
ethAddress = int("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",16)
daiAddress = int("0x00dA114221cb83fa859DBdb4C44bEeaa0BB37C7537ad5ae66Fe5e0efD20E6eB3",16)
usdcAddress = int("0x053C91253BC9682c04929cA02ED00b3E423f6710D2ee7e0D5EBB06F3eCF368A8",16)
ETH_USD_Key = 19514442401534788
DAI_USD_Key = 19212080998863684
USDC_USD_Key = 6148332971638477636
EMPIRIC_ORACLE_ADDRESS = int("0x0346c57f094d641ad94e43468628d8e9c574dcb2803ec372576ccc60a40be2c4",16)
JediSwapRouter = int("0x041fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388411c5e230f97023",16)
TenKRouter = int("0x07a6f98c03379b9513ca84cca1373ff452a7462a3b61598f0af5bb27ad7f76d1",16)
MySwap = int("0x07a6f98c03379b9513ca84cca1373ff452a7462a3b61598f0af5bb27ad7f76d1",16)

#Setup Admin Account
private_key = int("0xcf6efa9f2e5c349ea7b936f86771a1f3",16)
account_address = int("0x31cc6334a599584cdda006716992e7e60af6e3b03eda692b2719ca678cfa9f4",16)
public_key = private_to_stark_key(private_key)
signer_key_pair = KeyPair(private_key,public_key)
client = AccountClient(address=account_address, client=GatewayClient(net="http://127.0.0.1:5050/"), key_pair=signer_key_pair, chain=StarknetChainId.TESTNET, supported_tx_version=1)

erc20_abi = erc20_abi = [
    {
    "name": "Uint256",
    "size": 2,
    "type": "struct",
    "members": [
      {
        "name": "low",
        "type": "felt",
        "offset": 0
      },
      {
        "name": "high",
        "type": "felt",
        "offset": 1
      }
    ]
  },
  {
    "name": "transfer",
    "type": "function",
    "inputs": [
      {
        "name": "recipient",
        "type": "felt"
      },
      {
        "name": "amount",
        "type": "Uint256"
      }
    ],
    "outputs": [
      {
        "name": "res",
        "type": "felt"
      }
    ]
  },
  {
    "name": "balanceOf",
    "type": "function",
    "inputs": [
      {
        "name": "user",
        "type": "felt"
      }
    ],
    "outputs": [
      {
        "name": "res",
        "type": "Uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "name": "approve",
    "type": "function",
    "inputs": [
      {
        "name": "user",
        "type": "felt"
      }
    ],
    "outputs": [
      {
        "name": "res",
        "type": "Uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "name": "approve",
    "type": "function",
    "inputs": [
      {
        "name": "spender",
        "type": "felt"
      },
      {
        "name": "amount",
        "type": "Uint256"
      }
    ],
    "outputs": [
      {
        "name": "success",
        "type": "felt"
      }
    ]
  },
]

file = open('./build/hub_abi.json')
hub_abi = json.load(file)
file.close()

file = open('./build/router-aggregator_abi.json')
router_aggregator_abi = json.load(file)
file.close()

ETH_Contract = Contract(address=ethAddress, abi=erc20_abi, client=client)
DAI_Contract = Contract(address=daiAddress, abi=erc20_abi, client=client)
USDC_Contract = Contract(address=usdcAddress, abi=erc20_abi, client=client)