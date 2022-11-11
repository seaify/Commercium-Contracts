.PHONY: build test coverage

build:
	$(MAKE) clean
	protostar build --cairo-path ./lib/cairo_contracts/src --disable-hint-validation

setup:
	protostar install OpenZeppelin/cairo-contracts@v0.5.0
	pip install cairo-toolkit

format:
	poetry run cairo-format src/**/*.cairo -i

format-check:
	poetry run cairo-format src/**/*.cairo -c

gen-interfaces:
	rm -rf interfaces
	mkdir interfaces
	cairo-toolkit generate-interface -p -d ./src/interfaces

clean:
	rm -rf build
	mkdir build

lint:
	amarna ./src/kakarot -o lint.sarif -rules unused-imports,dead-store,unknown-decorator,unused-arguments