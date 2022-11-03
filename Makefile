.PHONY: build test coverage

build:
	$(MAKE) clean
	protostar build

setup:
	poetry install --no-root
	curl -L https://raw.githubusercontent.com/software-mansion/protostar/master/install.sh | bash
	source /home/runner/.bashrc
	
test:
	protostar test ./tests

format:
	poetry run cairo-format src/**/*.cairo -i

format-check:
	poetry run cairo-format src/**/*.cairo -c

clean:
	rm -rf build
	mkdir build
