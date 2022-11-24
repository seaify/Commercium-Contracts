# CommerciumContracts - A Fully On-Chain Aggregator

## Installation

Install the requirements (LINUX):

```bash
#Install Protostar
#curl -L https://raw.githubusercontent.com/software-mansion/protostar/master/install.sh | bash -s -- -v $PROTOSTAR_VERSION
make setup
```

## Compile Contracts

```bash
make build
```

## Generate Interfaces

```bash
make gen-interfaces
```

## Test

```bash
# Run all tests
make test
```

## Deploy The Protocol

```bash
# 1) Create a .secret file in the root directory and paste your private key of the account contract that you'll be using to deploy the contracts
# 2) Set the account_address variable in ./scripts/deploy_protocol.py (Set it to the public address of the account you'll be using to deploy)
make deploy-protocol
```
