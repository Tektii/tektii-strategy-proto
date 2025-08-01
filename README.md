# Tektii Strategy Protocol

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
┌─────────────────┐              ┌──────────────────┐              ┌─────────────────┐
│                 │   gRPC       │                  │  Provider    │                 │
│ Trading Strategy│ ◄──────────► │ Provider Adapter │ ◄─────────► │ Broker/Exchange │
│                 │              │                  │     API      │                 │
└─────────────────┘              └──────────────────┘              └─────────────────┘
     ▲                                    ▲
     │                                    │
     └────────────────────────────────────┘
          Bidirectional gRPC Connection

Your Strategy Code                Our Interface                   Any Trading Provider
```

### Service Architecture

The protocol defines two complementary gRPC services:

1. **TektiiStrategy** (implemented by your strategy):
   - Receives market events and trading updates
   - Handles initialization and shutdown
   - Processes events internally without returning trading actions

2. **TektiiBroker** (implemented by provider adapters):
   - Handles order management (place, cancel, modify)
   - Provides market data and state queries
   - Performs risk checks and validation

This separation ensures:
- Clear responsibility boundaries
- Strategies remain provider-agnostic
- Synchronous order operations with immediate feedback
- Event-driven market data processing

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
from trading.v1 import service_pb2_grpc, orders_pb2, common_pb2

class MyTradingStrategy(service_pb2_grpc.TektiiStrategyServicer):
    def __init__(self):
        # Connect to broker service
        channel = grpc.insecure_channel('localhost:50052')
        self.broker = service_pb2_grpc.TektiiBrokerStub(channel)
    
    def Initialize(self, request, context):
        # Initialize your strategy
        return orders_pb2.InitResponse(success=True)
    
    def ProcessEvent(self, request, context):
        # Handle market data events
        if request.HasField('tick_data'):
            # Make trading decision
            if should_buy(request.tick_data):
                # Call broker to place order
                order_request = orders_pb2.PlaceOrderRequest(
                    symbol=request.tick_data.symbol,
                    side=common_pb2.ORDER_SIDE_BUY,
                    order_type=common_pb2.ORDER_TYPE_MARKET,
                    quantity=100
                )
                response = self.broker.PlaceOrder(order_request)
                if response.accepted:
                    print(f"Order placed: {response.order_id}")
        
        return orders_pb2.ProcessEventResponse(success=True)

# Start the strategy gRPC server
server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
service_pb2_grpc.add_TektiiStrategyServicer_to_server(MyTradingStrategy(), server)
server.add_insecure_port('[::]:50051')
server.start()
```

#### Go Example

```go
package main

import (
    "context"
    "log"
    pb "github.com/Tektii/tektii-strategy-proto/gen/go/trading/v1"
    "google.golang.org/grpc"
)

type MyTradingStrategy struct {
    pb.UnimplementedTektiiStrategyServer
    brokerClient pb.TektiiBrokerClient
}

func NewStrategy() (*MyTradingStrategy, error) {
    // Connect to broker service
    conn, err := grpc.Dial("localhost:50052", grpc.WithInsecure())
    if err != nil {
        return nil, err
    }
    
    return &MyTradingStrategy{
        brokerClient: pb.NewTektiiBrokerClient(conn),
    }, nil
}

func (s *MyTradingStrategy) Initialize(ctx context.Context, req *pb.InitRequest) (*pb.InitResponse, error) {
    // Initialize your strategy
    return &pb.InitResponse{Success: true}, nil
}

func (s *MyTradingStrategy) ProcessEvent(ctx context.Context, req *pb.TektiiEvent) (*pb.ProcessEventResponse, error) {
    // Handle market data events
    if tick := req.GetTickData(); tick != nil {
        // Make trading decision
        if shouldBuy(tick) {
            // Call broker to place order
            orderReq := &pb.PlaceOrderRequest{
                Symbol:    tick.Symbol,
                Side:      pb.OrderSide_ORDER_SIDE_BUY,
                OrderType: pb.OrderType_ORDER_TYPE_MARKET,
                Quantity:  100,
            }
            
            resp, err := s.brokerClient.PlaceOrder(ctx, orderReq)
            if err != nil {
                log.Printf("Failed to place order: %v", err)
            } else if resp.Accepted {
                log.Printf("Order placed: %s", resp.OrderId)
            }
        }
    }
    
    return &pb.ProcessEventResponse{Success: true}, nil
}

func main() {
    strategy, err := NewStrategy()
    if err != nil {
        log.Fatal(err)
    }
    
    server := grpc.NewServer()
    pb.RegisterTektiiStrategyServer(server, strategy)
    // Start server...
}
```

## Message Types

### Service Definitions

**TektiiStrategy** (implemented by strategies):
- **Event Processing**: Handle market data and trading events
- **Lifecycle Management**: Initialize and shutdown operations

**TektiiBroker** (implemented by provider adapters):
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

### Connection Flow

1. **Provider adapter** starts and implements `TektiiBroker` service (port 50052)
2. **Strategy** starts and implements `TektiiStrategy` service (port 50051)
3. **Provider adapter** connects to strategy as a client
4. **Strategy** connects to provider adapter as a client
5. **Bidirectional communication** established:
   - Provider → Strategy: Market events, initialization, shutdown
   - Strategy → Provider: Order operations, state queries, risk checks

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
tektii-strategy-proto/
├── proto/
│   └── trading/
│       └── v1/
│           ├── service.proto     # Service definitions (TektiiStrategy & TektiiBroker)
│           ├── orders.proto      # Order management and event messages
│           ├── market_data.proto # Market data messages
│           └── common.proto      # Shared types and enums
├── gen/                          # Generated code (git ignored)
├── examples/                     # Example implementations
├── docs/                         # Documentation
├── Makefile                      # Build commands for linting and checks
└── README.md

Note: The buf.yaml configuration is located in the proto/ directory.
```

### Building

```bash
# Run all checks (lint + build)
make check

# Lint proto files
make lint

# Format proto files
make format

# Detect breaking changes
make breaking

# Generate code (from proto directory)
cd proto && buf generate
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
- **Issues**: [GitHub Issues](https://github.com/Tektii/tektii-strategy-proto/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Tektii/tektii-strategy-proto/discussions)

## Acknowledgments

This interface design is inspired by industry standards including:
- FIX Protocol
- Interactive Brokers API
- Alpaca Trading API
- CQG API

---

Built with ❤️ for the algorithmic trading community