from starknet_py.net.account.account_client import (AccountClient)
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.contract import Contract
from starknet_py.net.models import StarknetChainId
from starkware.crypto.signature.signature import private_to_stark_key
from starknet_py.net.gateway_client import GatewayClient
import asyncio
from pathlib import Path

#######################
#                     #
#     Global Info     #
#                     #
#######################

ethAddress = int("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",16)
daiAddress = int("0x03e85bfbb8e2a42b7bead9e88e9a1b19dbccf661471061807292120462396ec9",16)
usdcAddress = int("0x005a643907b9a4bc6a55e9069c4fd5fd1f5c79a22470690f75556c4736e34426",16)
ETH_USD_Key = 19514442401534788
DAI_USD_Key = 19212080998863684
USDC_USD_Key = 6148332971638477636
EMPIRIC_ORACLE_ADDRESS = int("0x446812bac98c08190dee8967180f4e3cdcd1db9373ca269904acb17f67f7093",16)
JediSwapRouter = int("0x012b063b60553c91ed237d8905dff412fba830c5716b17821063176c6c073341",16)
SithSwapRouter = int("0x015b7bac6b05fcb24f33011fefb592bf0579dae1d1f2a7d6645dda49849ece4d",16)
TenKRouter = int("0x00975910cd99bc56bd289eaaa5cee6cd557f0ddafdb2ce6ebea15b158eb2c664",16)
StarkSwapFactory = 0 #0x
AlphaRouter = int("0x04aec73f0611a9be0524e7ef21ab1679bdf9c97dc7d72614f15373d431226b6a",16)

#Setup Admin Account
private_key = int(Path("./.secret").read_text("utf-8"))
account_address = int("0x0000e6624768FB9550B82f667B8E3F7DB4A1E9548F173cDF1c9131497430EB7f",16)
public_key = private_to_stark_key(private_key)
signer_key_pair = KeyPair(private_key,public_key)
client = AccountClient(address=account_address, client=GatewayClient(net="http://127.0.0.1:5050/"), key_pair=signer_key_pair, chain=StarknetChainId.TESTNET, supported_tx_version=1)

contractAddresses = {
                    "hub": int("0x25b5b9a349742379e756b137307b7f3a768e0eecfe875c7c92e6a5070f6ff1d",16),
                    "solver_registry": int("0x03c9726d675877f2db7e838c92563bc3968f61b6b3191a5c942c23ecc0ecf320",16),
                    "router_aggregator": int("0x3aafd1a0d88dda388a456505a257f0bd9090ef373d57d0dc064a4cee500584c",16),
                    "single_swap_solver": int("0x589763fb3512c5c07b4e9f18b1e98dd6543e6fc6ae937fca59862dd3f045d7b",16),
                    "spf_solver": int("0x3708fc7fc0c879ededd9642ae7aac3f0a5fe7584a9815cd9e2c1d4c5a4608e7",16),
                    "heuristic_splitter": int("0x2b09acac144ac0be83807f07a7d908703b3fc1e8b227906a3090f4e2083ed6b",16)
                    }

erc20_abi = [
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
                    
router_aggregator_abi = [
    {
        "inputs": [
            {"name": "_token", "type": "felt"},
            {"name": "_key", "type": "felt"},
            {"name": "_oracle_address", "type": "felt"},
        ],
        "name": "set_global_price",
        "outputs": [],
        "type": "function",
    },
    {
        "inputs": [
            {"name": "_router_address", "type": "felt"},
            {"name": "_router_type", "type": "felt"},
        ],
        "name": "add_router",
        "outputs": [],
        "type": "function",
    }
]

hub_abi = [
    {
        "members": [
            {
                "name": "low",
                "offset": 0,
                "type": "felt"
            },
            {
                "name": "high",
                "offset": 1,
                "type": "felt"
            }
        ],
        "name": "Uint256",
        "size": 2,
        "type": "struct"
    },
    {
        "members": [
            {
                "name": "address",
                "offset": 0,
                "type": "felt"
            },
            {
                "name": "type",
                "offset": 1,
                "type": "felt"
            }
        ],
        "name": "Router",
        "size": 2,
        "type": "struct"
    },
    {
        "members": [
            {
                "name": "token_in",
                "offset": 0,
                "type": "felt"
            },
            {
                "name": "token_out",
                "offset": 1,
                "type": "felt"
            }
        ],
        "name": "Path",
        "size": 2,
        "type": "struct"
    },
    {
        "data": [
            {
                "name": "previousOwner",
                "type": "felt"
            },
            {
                "name": "newOwner",
                "type": "felt"
            }
        ],
        "keys": [],
        "name": "OwnershipTransferred",
        "type": "event"
    },
    {
        "data": [
            {
                "name": "solver_used",
                "type": "felt"
            },
            {
                "name": "amount_traded",
                "type": "Uint256"
            },
            {
                "name": "token_sold",
                "type": "felt"
            }
        ],
        "keys": [],
        "name": "swap_executed",
        "type": "event"
    },
    {
        "inputs": [
            {
                "name": "_owner",
                "type": "felt"
            },
            {
                "name": "_execution_hash",
                "type": "felt"
            }
        ],
        "name": "constructor",
        "outputs": [],
        "type": "constructor"
    },
    {
        "inputs": [],
        "name": "solver_registry",
        "outputs": [
            {
                "name": "solver_registry",
                "type": "felt"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "trade_executor",
        "outputs": [
            {
                "name": "trade_executor",
                "type": "felt"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_amount_in",
                "type": "Uint256"
            },
            {
                "name": "_token_in",
                "type": "felt"
            },
            {
                "name": "_token_out",
                "type": "felt"
            },
            {
                "name": "_solver_id",
                "type": "felt"
            }
        ],
        "name": "get_amount_out_with_solver",
        "outputs": [
            {
                "name": "amount_out",
                "type": "Uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_amount_in",
                "type": "Uint256"
            },
            {
                "name": "_token_in",
                "type": "felt"
            },
            {
                "name": "_token_out",
                "type": "felt"
            },
            {
                "name": "_solver_id",
                "type": "felt"
            }
        ],
        "name": "get_amount_and_path_with_solver",
        "outputs": [
            {
                "name": "routers_len",
                "type": "felt"
            },
            {
                "name": "routers",
                "type": "Router*"
            },
            {
                "name": "path_len",
                "type": "felt"
            },
            {
                "name": "path",
                "type": "Path*"
            },
            {
                "name": "amounts_len",
                "type": "felt"
            },
            {
                "name": "amounts",
                "type": "felt*"
            },
            {
                "name": "amount_out",
                "type": "Uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_amount_in",
                "type": "Uint256"
            },
            {
                "name": "_token_in",
                "type": "felt"
            },
            {
                "name": "_token_out",
                "type": "felt"
            }
        ],
        "name": "get_amount_out",
        "outputs": [
            {
                "name": "amount",
                "type": "Uint256"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_amount_in",
                "type": "Uint256"
            },
            {
                "name": "_token_in",
                "type": "felt"
            },
            {
                "name": "_token_out",
                "type": "felt"
            },
            {
                "name": "_solver_ids_len",
                "type": "felt"
            },
            {
                "name": "_solver_ids",
                "type": "felt*"
            }
        ],
        "name": "get_multiple_solver_amounts",
        "outputs": [
            {
                "name": "amounts_out_len",
                "type": "felt"
            },
            {
                "name": "amounts_out",
                "type": "Uint256*"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_amount_in",
                "type": "Uint256"
            },
            {
                "name": "_amount_out_min",
                "type": "Uint256"
            },
            {
                "name": "_token_in",
                "type": "felt"
            },
            {
                "name": "_token_out",
                "type": "felt"
            },
            {
                "name": "_to",
                "type": "felt"
            }
        ],
        "name": "swap_exact_tokens_for_tokens",
        "outputs": [
            {
                "name": "amount_out",
                "type": "Uint256"
            }
        ],
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_amount_in",
                "type": "Uint256"
            },
            {
                "name": "_min_amount_out",
                "type": "Uint256"
            },
            {
                "name": "_token_in",
                "type": "felt"
            },
            {
                "name": "_token_out",
                "type": "felt"
            },
            {
                "name": "_to",
                "type": "felt"
            },
            {
                "name": "_solver_id",
                "type": "felt"
            }
        ],
        "name": "swap_exact_tokens_for_tokens_with_solver",
        "outputs": [
            {
                "name": "received_amount",
                "type": "Uint256"
            }
        ],
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_routers_len",
                "type": "felt"
            },
            {
                "name": "_routers",
                "type": "Router*"
            },
            {
                "name": "_path_len",
                "type": "felt"
            },
            {
                "name": "_path",
                "type": "Path*"
            },
            {
                "name": "_amounts_len",
                "type": "felt"
            },
            {
                "name": "_amounts",
                "type": "felt*"
            },
            {
                "name": "_amount_in",
                "type": "Uint256"
            },
            {
                "name": "_min_amount_out",
                "type": "Uint256"
            }
        ],
        "name": "swap_with_path",
        "outputs": [
            {
                "name": "received_amount",
                "type": "Uint256"
            }
        ],
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_new_registry",
                "type": "felt"
            }
        ],
        "name": "set_solver_registry",
        "outputs": [],
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_execution_hash",
                "type": "felt"
            }
        ],
        "name": "set_executor",
        "outputs": [],
        "type": "function"
    },
    {
        "inputs": [
            {
                "name": "_token_len",
                "type": "felt"
            },
            {
                "name": "_token",
                "type": "felt*"
            },
            {
                "name": "_token_amount_len",
                "type": "felt"
            },
            {
                "name": "_token_amount",
                "type": "Uint256*"
            }
        ],
        "name": "retrieve_tokens",
        "outputs": [],
        "type": "function"
    }
]

#############################
#                           #
#     Integration Tests     #
#                           #
#############################

async def fullTestSuite():
    #await deployContracts()
    await testSolvers([1])

async def deployContracts():

    print("---------------------------------")
    print("--- Deploying Entire Protocol ---")
    print("---------------------------------")
    print(".")
    print(".")
    print(".")

    # Declare Trade Executor Contract
    print("⏳ Declaring Executor Contract... ")
    declare_transaction = await client.sign_declare_transaction(
        compiled_contract=Path("./build/", "trade-executor.json").read_text("utf-8"), max_fee=int(1e16)
    )
    resp = await client.declare(transaction=declare_transaction)
    await client.wait_for_tx(resp.transaction_hash)
    execution_contract_hash = resp.class_hash
    print("Executor Class Hash: ", hex(execution_contract_hash))

    # Declare Router Aggregator Contract
    print("⏳ Declaring Router Aggregator Contract... ")
    declare_transaction = await client.sign_declare_transaction(
        compiled_contract=Path("./build/", "router-aggregator.json").read_text("utf-8"), max_fee=int(1e16)
    )
    resp = await client.declare(transaction=declare_transaction)
    await client.wait_for_tx(resp.transaction_hash)
    router_aggregator_contract_hash = resp.class_hash
    print("Executor Class Hash: ", hex(router_aggregator_contract_hash))

    # Deploy Hub
    print("Deploying Hub")
    compiled_contract = Path("./build/", "hub.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address,execution_contract_hash])
    print("Hub Address: ",contract_address)
    contractAddresses["hub"] = int(contract_address,16)

    # Deploy Solver Registry
    print("Deploying Solver Registry")
    compiled_contract = Path("./build/", "solver-registry.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address])
    print("Solver Registry Address: ",contract_address)
    contractAddresses["solver_registry"] = int(contract_address,16)

    # Deploy Router Aggregator
    print("Deploying Router Aggregator")
    compiled_contract = Path("./build/", "router-aggregator-proxy.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[router_aggregator_contract_hash,account_address,account_address])
    print("Router Aggregator Address: ",contract_address)
    contractAddresses["router_aggregator"] = int(contract_address,16)

    # Deploy Single Swap Solver
    print("Deploying Single Swap Solver")
    compiled_contract = Path("./build/", "single-swap-solver.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[contractAddresses["router_aggregator"]])
    print("Single Swap Solver Address: ",contract_address)
    contractAddresses["sigle_swap_solver"] = int(contract_address,16)

    # Deploy SPF Solver
    print("Deploying SPF Solver")
    compiled_contract = Path("./build/", "spf-solver.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[account_address,contractAddresses["router_aggregator"]])
    print("SPF Solver Address: ",contract_address)
    contractAddresses["spf_solver"] = int(contract_address,16)

    # Deploy Heuristic Splitter Solver
    print("Deploying Heuristic Splitter Solver")
    compiled_contract = Path("./build/", "heuristic-splitter.json").read_text("utf-8")
    contract_address = await deployContract(client=client,compiled_contract=compiled_contract,calldata=[contractAddresses["router_aggregator"],execution_contract_hash,contractAddresses["hub"]])
    print("Heuristic Splitter Address: ",contract_address)
    contractAddresses["heuristic_splitter"] = int(contract_address,16)
    
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

    #Configure Hub
    print("...Configuring Hub...")
    #Set Solver Registry
    invocation = await hubContract.functions["set_solver_registry"].invoke(solverRegistryContract.address,max_fee=50000000000000000000)
    print("Setting Solver Registry...")
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

async def testSolvers(solvers: list):

    print("Testing Solvers...")
    hubContract = Contract(address=contractAddresses["hub"], abi=hub_abi, client=client)
    erc20Contract = Contract(address=ethAddress, abi=erc20_abi, client=client)

    print("Hub Address: ", hubContract.address)
    print("ETH Address: ", ethAddress)
    print("DAI Address: ", daiAddress)
    
    #(res,) = await hubContract.functions["solver_registry"].call()
    #print("Getting Amount out...")
    #(res,) = await hubContract.functions["get_amount_out"].call({"low": 1000000, "high":0},ethAddress,daiAddress)
    
    print("Approving trade...")
    invocation = await erc20Contract.functions["approve"].invoke(hubContract.address,{"low": 1000000, "high":0},max_fee=50000000000000000000)
    print("Waiting for acceptance...")
    await invocation.wait_for_acceptance()
    print("Approving trade...")
    invocation = await erc20Contract.functions["approve"].invoke(hubContract.address,{"low": 1000000, "high":0},max_fee=50000000000000000000)
    print("Waiting for acceptance...")
    await invocation.wait_for_acceptance()
    print("Approving trade...")
    invocation = await erc20Contract.functions["approve"].invoke(hubContract.address,{"low": 1000000, "high":0},max_fee=50000000000000000000)
    print("Waiting for acceptance...")
    await invocation.wait_for_acceptance()
    print("Setting Registry...")
    invocation = await hubContract.functions["set_solver_registry"].invoke(account_address,max_fee=50000000000000000000)
    await invocation.wait_for_acceptance()
    
    
    #print("Performing trade...")
    #invocation = await hubContract.functions["swap_exact_tokens_for_tokens"].invoke({"low": 1000000, "high":0},{"low": 0, "high":0},ethAddress,daiAddress,account_address,max_fee=50000000000000000000)
    #print("Waiting for acceptance...")
    #await invocation.wait_for_acceptance()

#Deploy a Contract
async def deployContract(client: AccountClient,compiled_contract: str, calldata) -> (str):
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=int(1e16)
    )
    print("⏳ Waiting for decleration...")
    await declare_result.wait_for_acceptance()

    deploy_result = await declare_result.deploy(max_fee=int(1e16), constructor_args=calldata)
    print("⏳ Waiting for deployment...")
    await deploy_result.wait_for_acceptance()
    contract = deploy_result.deployed_contract
    return hex(contract.address)

asyncio.run(fullTestSuite())


