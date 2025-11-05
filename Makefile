.PHONY: build test clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  make build       - Compile all contracts"
	@echo "  make test        - Run all tests"
	@echo "  make clean       - Clean build artifacts"

# Build all contracts
build:
	forge build

# Run all tests
test:
	forge test -vv

# Clean build artifacts
clean:
	forge clean
