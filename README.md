# Trading Interface Protocol

[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Buf](https://img.shields.io/badge/Buf-Schema%20Registry-blueviolet)](https://buf.build)

The official Protocol Buffer interface definitions for the Tektii algorithmic trading platform. This interface enables trading strategies to integrate with Tektii's infrastructure and supported brokers/exchanges.

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

This repository defines a standardized gRPC service interface that acts as an abstraction layer between trading strategies and various trading providers (brokers, exchanges, etc.). By implementing this interface, trading strategies become portable across different providers without requiring code changes.

### Key Features

- **Provider Agnostic**: Write once, trade anywhere
- **Type Safety**: Strongly typed with Protocol Buffers
- **Multi-Language Support**: Generate clients for Go, Python, Java, C++, Rust, and more
- **Event-Driven Architecture**: Real-time market data and order updates
- **Synchronous Order Management**: Immediate feedback on order operations
- **Risk Management**: Built-in pre-trade risk checks and validation
- **Comprehensive Data Types**: Support for equities, futures, options, and crypto

## Architecture

```
┌─────────────────┐     gRPC      ┌──────────────────┐     Provider API    ┌─────────────────┐
│                 │ ◄──────────► │                  │ ◄────────────────► │                 │
│ Trading Strategy│               │ Provider Adapter │                     │ Broker/Exchange │
│                 │               │                  │                     │                 │
└─────────────────┘               └──────────────────┘                     └─────────────────┘

Your Strategy Code                Our Interface                            Any Trading Provider
```

## Quick Start

### 1. Install Buf (Protocol Buffer toolchain)

```bash
# macOS
brew install bufbuild/buf/buf

# Linux
curl -sSL https://github.com/bufbuild/buf/releases/download/v1.28.1/buf-Linux-x86_64 \
  -o /usr/local/bin/buf && chmod +x /usr/local/bin/buf
```

### 2. Generate Code for Your Language

```bash
# Generate code for all configured languages
buf generate

# Generate only for specific languages
buf generate --template buf.gen.yaml --include-imports
```

### 3. Implement the Interface

#### Python Example

```python
from concurrent import futures
import grpc
from trading.v1 import orders_pb2_grpc, orders_pb2, common_pb2

class MyTradingStrategy(orders_pb2_grpc.TradingServiceServicer):
    def Initialize(self, request, context):
        # Initialize your strategy
        return orders_pb2.InitResponse(success=True)
    
    def ProcessEvent(self, request, context):
        # Handle market data events
        if request.HasField('tick_data'):
            self.handle_tick(request.tick_data)
        return orders_pb2.ProcessEventResponse(success=True)
    
    def PlaceOrder(self, request, context):
        # Validate and place orders
        # This is called by your strategy when it wants to trade
        pass

# Start the gRPC server
server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
orders_pb2_grpc.add_TradingServiceServicer_to_server(MyTradingStrategy(), server)
server.add_insecure_port('[::]:50051')
server.start()
```

#### Go Example

```go
package main

import (
    "context"
    pb "github.com/your-org/trading-interface-proto/gen/go/trading/v1"
    "google.golang.org/grpc"
)

type MyTradingStrategy struct {
    pb.UnimplementedTradingServiceServer
}

func (s *MyTradingStrategy) Initialize(ctx context.Context, req *pb.InitRequest) (*pb.InitResponse, error) {
    // Initialize your strategy
    return &pb.InitResponse{Success: true}, nil
}

func (s *MyTradingStrategy) ProcessEvent(ctx context.Context, req *pb.TradingEvent) (*pb.ProcessEventResponse, error) {
    // Handle market data events
    return &pb.ProcessEventResponse{Success: true}, nil
}

func main() {
    server := grpc.NewServer()
    pb.RegisterTradingServiceServer(server, &MyTradingStrategy{})
    // Start server...
}
```

## Message Types

### Service Definition

The main service `TradingService` provides:

- **Event Processing**: Handle market data and trading events
- **Order Management**: Place, cancel, and modify orders with immediate feedback
- **Risk Management**: Validate orders and check risk metrics
- **Data Queries**: Get historical data, market depth, and current state

### Event Types

Events are delivered via the `ProcessEvent` RPC:

- **Market Data**: Ticks, bars (OHLCV), option Greeks
- **Order Updates**: Status changes, fills, rejections
- **Position Updates**: P&L, quantity changes
- **Account Updates**: Balance, margin, buying power
- **System Events**: Connection status, errors

### Order Types

Supported order types with full lifecycle management:

- Market orders
- Limit orders
- Stop orders
- Stop-limit orders
- Protective orders (stop loss, take profit)

## Integration Guide

For detailed integration instructions, see [docs/integration-guide.md](docs/integration-guide.md).

## Supported Providers

Adapters are available or planned for:

- Interactive Brokers
- Alpaca
- TD Ameritrade
- E*TRADE
- Binance
- Coinbase
- Kraken
- FIX Protocol (generic)
- And more...

## Development

### Project Structure

```
trading-interface-proto/
├── proto/
│   └── trading/
│       └── v1/
│           ├── orders.proto      # Order management and main service
│           ├── market_data.proto # Market data messages
│           └── common.proto      # Shared types and enums
├── gen/                          # Generated code (git ignored)
├── examples/                     # Example implementations
├── docs/                         # Documentation
├── buf.yaml                      # Buf configuration
├── buf.gen.yaml                  # Code generation configuration
└── README.md
```

### Building

```bash
# Lint proto files
buf lint

# Detect breaking changes
buf breaking --against '.git#branch=main'

# Generate code
buf generate
```

### Testing

```bash
# Run example strategies
cd examples/python && python -m pytest
cd examples/go && go test ./...
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run linting and tests
5. Submit a pull request

## License

This project is licensed under the Tektii Platform Interface License - see the [LICENSE](LICENSE) file for details.

**Important**: This software is restricted to use with the Tektii platform only. See license for full terms.

## Support

- **Documentation**: [Full Documentation](docs/)
- **Examples**: [Example Implementations](examples/)
- **Issues**: [GitHub Issues](https://github.com/your-org/trading-interface-proto/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/trading-interface-proto/discussions)

## Acknowledgments

This interface design is inspired by industry standards including:
- FIX Protocol
- Interactive Brokers API
- Alpaca Trading API
- CQG API

---

Built with ❤️ for the algorithmic trading community