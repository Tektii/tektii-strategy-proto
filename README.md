# Tektii Strategy Proto

Protocol Buffer definitions for Tektii's generic trading interface.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Local Development Setup](#local-development-setup)
  - [Making Changes](#making-changes)
- [Integration Guide](#integration-guide)
  - [For Strategy Developers](#for-strategy-developers)
  - [For Provider Adapter Developers](#for-provider-adapter-developers)
- [Proto Design](#proto-design)
  - [Service Methods](#service-methods)
  - [Event Types](#event-types)
  - [Design Principles](#design-principles)
- [Language-Specific Implementation](#language-specific-implementation)
- [Testing](#testing)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)

## Overview

This repository contains the protobuf specification that defines how trading strategies communicate with various trading providers (brokers, exchanges, backtesting engines) through a unified interface. 

**Key Benefits:**
- **Write Once, Trade Anywhere**: Strategies work with any supported provider without code changes
- **Provider Agnostic**: Abstract away provider-specific APIs and quirks
- **Type Safety**: Strongly typed interfaces with built-in validation
- **Industry Standard**: Based on gRPC for reliable, high-performance communication

### What This Repo Is

- 📋 **Contract Definition**: The single source of truth for the trading interface
- 🔌 **Integration Point**: Where strategies and providers meet
- 📐 **Specification**: Defines all messages, services, and validation rules

### What This Repo Is NOT

- ❌ **Implementation**: No strategy or provider code lives here
- ❌ **Business Logic**: Just the interface, not the logic
- ❌ **Provider-Specific**: Remains generic and neutral

## Architecture

```
┌─────────────────┐         gRPC          ┌──────────────────┐
│ Trading Strategy│◄──────────────────────►│ Provider Adapter │
│  (Any Language) │   TektiiStrategy       │  (Platform Side) │
└─────────────────┘      Service           └──────────────────┘
        ▲                                            │
        │                                            ▼
        │                                   ┌────────────────┐
        └───────── Uses this proto ────────►│ Specific Broker│
                                            │      API       │
                                            └────────────────┘
```

### Communication Flow

1. **Event-Driven Market Data**: Provider sends market events to strategy via `ProcessEvent`
2. **Synchronous Order Management**: Strategy sends orders and gets immediate feedback
3. **State Queries**: Strategy can query current positions, orders, and market data

## Getting Started

### Prerequisites

- **macOS/Linux**: Primary development platforms
- **Protocol Buffers**: `protoc` compiler (optional, buf handles this)
- **buf CLI**: For linting and breaking change detection
- **protolint**: Additional proto linting
- **Make**: For running development commands

### Local Development Setup

```bash
# Clone the repository
git clone https://github.com/tektii/tektii-strategy-proto.git
cd tektii-strategy-proto

# Install development tools (macOS)
make install

# Verify setup
make check
```

### Making Changes

1. **Edit `strategy.proto`**: Make your changes to the proto file
2. **Run Quality Checks**: `make check` runs all linting and validation
3. **Check for Breaking Changes**: `make breaking` compares against main branch
4. **Commit with Conventional Format**: 
   ```bash
   git add strategy.proto
   git commit -m "feat: add market depth request message"
   ```

## Integration Guide

### For Strategy Developers

If you're building a trading strategy that uses this interface:

1. **Choose Your Language**: Go, Python, Rust, or any gRPC-supported language
2. **Generate Code**: Use buf or protoc to generate client/server code
3. **Implement the Service**: Create a gRPC server that implements `TektiiStrategy`
4. **Handle Events**: Process market events and return appropriate actions

Example Python setup:
```bash
# Using the Tektii Python SDK (recommended)
pip install tektii-strategy-sdk

# Or generate your own
buf generate --template buf.gen.python.yaml
```

### For Provider Adapter Developers

If you're building an adapter for a specific broker/exchange:

1. **Generate Client Code**: Create a gRPC client for `TektiiStrategy`
2. **Map Provider Events**: Convert provider-specific events to `TektiiEvent`
3. **Translate Orders**: Convert generic orders to provider-specific API calls
4. **Handle Responses**: Map provider responses back to proto messages

### Consuming This Proto

#### Option 1: Via buf.build Registry (Recommended)

```yaml
# buf.yaml
version: v1
deps:
  - buf.build/tektii/strategy-proto
```

#### Option 2: As Git Submodule

```bash
git submodule add https://github.com/tektii/tektii-strategy-proto.git proto/tektii
```

#### Option 3: Direct Download

Download `strategy.proto` and include in your project.

## Proto Design

### Service Methods

The `TektiiStrategy` service defines these RPC methods:

#### Event Processing
- `ProcessEvent`: Receives market/trading events (one-way communication)

#### Order Management (Synchronous)
- `PlaceOrder`: Submit orders with immediate acceptance/rejection
- `CancelOrder`: Cancel existing orders with confirmation
- `ModifyOrder`: Modify order parameters with validation
- `ValidateOrder`: Pre-trade risk check without placing
- `ClosePosition`: Close positions with order creation
- `ModifyTradeProtection`: Manage stop loss/take profit

#### Lifecycle
- `Initialize`: Strategy initialization with configuration
- `Shutdown`: Graceful shutdown

#### Queries
- `GetState`: Current positions, orders, and account state
- `GetHistoricalData`: Historical market data
- `GetMarketDepth`: Order book/market depth
- `GetRiskMetrics`: Portfolio risk calculations

### Event Types

Events are wrapped in the `TektiiEvent` message:

```protobuf
message TektiiEvent {
  oneof event {
    TickData tick_data = 1;
    BarData bar_data = 2;
    OrderUpdateEvent order_update = 3;
    PositionUpdateEvent position_update = 4;
    // ... more event types
  }
}
```

### Design Principles

1. **Provider Neutrality**: No provider-specific fields in core messages
2. **Extensibility**: Use metadata maps for custom data
3. **Backward Compatibility**: Never remove or renumber fields
4. **Validation**: Built-in constraints using `validate.proto`
5. **Clarity**: Clear field names and comprehensive comments

## Language-Specific Implementation

### Go

```bash
# Generate with buf
buf generate

# Or with protoc
protoc --go_out=. --go-grpc_out=. strategy.proto
```

Example implementation:
```go
type strategyServer struct {
    pb.UnimplementedTektiiStrategyServer
}

func (s *strategyServer) ProcessEvent(ctx context.Context, req *pb.ProcessEventRequest) (*pb.ProcessEventResponse, error) {
    switch event := req.Event.Event.(type) {
    case *pb.TektiiEvent_TickData:
        // Handle tick data
    case *pb.TektiiEvent_BarData:
        // Handle bar data
    }
    return &pb.ProcessEventResponse{}, nil
}
```

### Python

```bash
# Using Tektii SDK (recommended)
pip install tektii-strategy-sdk

# Or generate manually
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. strategy.proto
```

Example implementation:
```python
from tektii_strategy_sdk import BaseStrategy
from tektii_proto import strategy_pb2 as pb

class MyStrategy(BaseStrategy):
    def process_event(self, event: pb.TektiiEvent):
        if event.HasField("tick_data"):
            # Handle tick data
            pass
        elif event.HasField("bar_data"):
            # Handle bar data
            pass
```

### Rust

```toml
# Cargo.toml
[dependencies]
tonic = "0.10"
prost = "0.12"

[build-dependencies]
tonic-build = "0.10"
```

```rust
// build.rs
fn main() {
    tonic_build::compile_protos(&["strategy.proto"], &["."])
        .expect("Failed to compile protos");
}
```

## Testing

### Unit Testing Your Strategy

1. **Mock the gRPC Service**: Use language-specific mocking tools
2. **Test Event Processing**: Send sample events and verify responses
3. **Test Order Logic**: Verify order placement under different conditions
4. **Test Error Handling**: Ensure graceful handling of failures

### Integration Testing

1. **Use Test Provider**: Connect to a paper trading or test environment
2. **Replay Historical Data**: Test with real market data sequences
3. **Validate State Management**: Ensure positions and orders track correctly

### Example Test Structure

```
tests/
├── unit/
│   ├── test_event_processing.py
│   ├── test_order_management.py
│   └── test_risk_checks.py
├── integration/
│   ├── test_provider_connection.py
│   └── test_end_to_end_flow.py
└── fixtures/
    ├── sample_events.json
    └── expected_orders.json
```

## Contributing

### Development Workflow

1. **Fork and Clone**: Fork the repo and clone locally
2. **Create Branch**: `git checkout -b feature/your-feature`
3. **Make Changes**: Edit `strategy.proto` with your changes
4. **Run Checks**: `make check` must pass
5. **Test Breaking Changes**: `make breaking` to ensure compatibility
6. **Commit**: Use conventional commits (feat:, fix:, docs:, etc.)
7. **Push and PR**: Push branch and create pull request

### Pull Request Guidelines

- **Title**: Use conventional commit format
- **Description**: Explain what and why
- **Breaking Changes**: Clearly mark if breaking
- **Testing**: Describe testing approach
- **Documentation**: Update README if needed

### Code Review Process

1. Automated checks must pass (linting, breaking changes)
2. At least one maintainer approval required
3. Discussion on design decisions if needed
4. Squash and merge to maintain clean history

## Troubleshooting

### Common Issues

#### "Import not found" Errors
- Ensure you have the latest proto file
- Check your import paths match the package name
- Verify buf.yaml configuration if using buf

#### Validation Failures
- Check field constraints in proto comments
- Use proper validation libraries for your language
- Ensure all required fields are populated

#### gRPC Connection Issues
- Verify server is running on correct port
- Check firewall/network settings
- Enable gRPC logging for debugging

#### Breaking Change Detected
- Review the breaking change carefully
- If intentional, update major version
- If accidental, revert the change
- Coordinate with all consumers before merging

### Getting Help

- 📖 Check existing issues: [GitHub Issues](https://github.com/tektii/tektii-strategy-proto/issues)
- 💬 Ask in discussions: [GitHub Discussions](https://github.com/tektii/tektii-strategy-proto/discussions)
- 📧 Email: engineering@tektii.com

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.