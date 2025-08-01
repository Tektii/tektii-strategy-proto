.PHONY: install lint format breaking check clean all

# Default target
all: check

# Install development tools
install:
	@echo "Installing buf..."
	@brew install bufbuild/buf/buf || (echo "Please install buf manually from https://github.com/bufbuild/buf" && exit 1)
	@echo "All tools installed!"

# Lint proto files
lint:
	@echo "Running buf lint..."
	@cd proto && buf lint
	@echo "Linting complete!"

# Format proto files
format:
	@echo "Formatting proto files..."
	@cd proto && buf format -w
	@echo "Formatting complete!"

# Run all checks
check: lint breaking
	@echo "Running all checks..."
	@cd proto && buf build
	@echo "All checks passed!"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -rf .buf/
	@echo "Clean complete!"

# Show current proto structure
show-structure:
	@echo "Current proto structure:"
	@find proto -name "*.proto" | sort

# Validate proto compilation
validate:
	@echo "Validating proto files..."
	@cd proto && buf build
	@echo "Proto files are valid!"

# Help target
help:
	@echo "Available targets:"
	@echo "  make install    - Install required development tools"
	@echo "  make lint       - Run linting on proto files"
	@echo "  make format     - Format proto files"
	@echo "  make breaking   - Check for breaking changes"
	@echo "  make check      - Run all checks (lint + build)"
	@echo "  make clean      - Remove temporary files"
	@echo "  make validate   - Validate proto compilation"
	@echo "  make show-structure - Display current proto file structure"
	@echo "  make help       - Show this help message"