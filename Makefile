.PHONY: build test clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  make install     - Install all dependencies"
	@echo "  make build       - Compile all contracts"
	@echo "  make test        - Run all tests"
	@echo "  make clean       - Clean build artifacts"

# Install all dependencies
install:
	forge soldeer install

# Build all contracts
build:
	forge build

# Run all tests
test:
	forge test -vv

# Clean build artifacts
clean:
	forge clean
