-include .env

.PHONY: build test clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  make install				- Install all dependencies"
	@echo "  make build       			- Compile all contracts"
	@echo "  make test        			- Run all tests"
	@echo "  make clean       			- Clean build artifacts"
	@echo "  make simulate-deploy		- Simulate hook deployment"
	@echo "  make deploy      			- Deploy hook"

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

# Simulate hook deployment 
simulate-deploy:
	forge script script/DeployHookTargetAccessControlKeyringSidePocket.s.sol \
	--rpc-url $(RPC_URL) \
	-vvvv 

# Deploy hook 
deploy:
	forge script script/DeployHookTargetAccessControlKeyringSidePocket.s.sol \
	--rpc-url $(RPC_URL) \
	--broadcast \
	--verify \
	--verifier-url $(VERIFIER_URL) \
	--etherscan-api-key $(ETHERSCAN_API_KEY) \
	--retries 20 \
	-vvvv 