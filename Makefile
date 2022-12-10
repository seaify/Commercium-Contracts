.PHONY: build test coverage


setup:
	protostar install
	pip install cairo-toolkit

build:
	$(MAKE) clean
	protostar build --cairo-path ./lib/cairo_contracts/src --disable-hint-validation

test:
	protostar test ./tests --disable-hint-validation

test-integration:
	python ./tests/integration/basic_test.py

mainnet-fork:
	starknet-devnet --fork-network alpha-mainnet --seed 2492750914	--gas-price 0

format:
	poetry run cairo-format src/**/*.cairo -i

format-check:
	poetry run cairo-format src/**/*.cairo -c

gen-interfaces:
	cairo-toolkit generate-interface -p -d ./src/interfaces

clean:
	rm -rf build
	mkdir build

lint:
	amarna ./src/kakarot -o lint.sarif -rules unused-imports,dead-store,unknown-decorator,unused-arguments

deploy-protocol:
	python ./scripts/deploy_protocol.py