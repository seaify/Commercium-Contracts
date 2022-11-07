.PHONY: build test coverage

build:
	$(MAKE) clean
	protostar build --cairo-path ./lib/cairo_contracts/src --disable-hint-validation

setup:
	poetry install --no-root
	curl -L https://raw.githubusercontent.com/software-mansion/protostar/master/install.sh | bash
	protostar install OpenZeppelin/cairo-contracts@v0.5.0

format:
	poetry run cairo-format src/**/*.cairo -i

format-check:
	poetry run cairo-format src/**/*.cairo -c

clean:
	rm -rf build
	mkdir build

lint:
	amarna ./src/kakarot -o lint.sarif -rules unused-imports,dead-store,unknown-decorator,unused-arguments