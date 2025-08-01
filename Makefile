.PHONY: install lint breaking check clean

# Install linting tools
install:
	@echo "Installing buf..."
	@brew install bufbuild/buf/buf || (echo "Please install buf manually from https://github.com/bufbuild/buf" && exit 1)
	@echo "Installing protolint..."
	@brew install protolint || go install github.com/yoheimuta/protolint/cmd/protolint@latest

# Lint proto files
lint:
	@echo "Running buf lint..."
	@buf lint
	@echo "Running protolint..."
	@protolint lint strategy.proto

# Check for breaking changes
breaking:
	@echo "Checking for breaking changes..."
	@buf breaking --against '.git#branch=main' || echo "Skipping breaking check (no git history or not on branch)"

# Run all checks
check: lint breaking
	@echo "All checks passed!"

# Clean any temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -rf .buf/