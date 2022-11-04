.PHONY: build test coverage

build:
	$(MAKE) clean

setup:
	poetry install --no-root

format:
	poetry run cairo-format src/**/*.cairo -i

format-check:
	poetry run cairo-format src/**/*.cairo -c

clean:
	rm -rf build
	mkdir build