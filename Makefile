.PHONY: build test coverage

build:
	$(MAKE) clean
	protostar build

setup:
	poetry install --no-root
	
	
test:
	

format:
	cairo-format src/**/*.cairo -i

format-check:
	cairo-format src/**/*.cairo -c

clean:
	rm -rf build
	mkdir build
