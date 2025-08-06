# Tektii Strategy Protocol

This module defines the gRPC service interface for implementing trading strategies on the Tektii platform.

## Overview

The Strategy Protocol provides a standardized interface that allows trading strategies to:
- Receive market data and trading events through a unified event stream
- Execute trading operations (place, modify, cancel orders)
- Query current state and historical data
- Manage strategy lifecycle (initialization and shutdown)

## Architecture

The module implements a hybrid event-driven and synchronous RPC pattern:

- **Event Processing**: Market data and updates are pushed to strategies via the `ProcessEvent` RPC
- **Order Management**: Trading operations use synchronous RPCs for immediate feedback and validation
- **Query Operations**: Pull-based data access for state, historical data, and risk metrics

## Key Components

### Service Definition
- `strategy_service.proto`: Main gRPC service definition with all RPC methods

### Event Types
- `event_tick_data.proto`: High-frequency quote and trade data
- `event_candle_data.proto`: OHLCV aggregated market data
- `event_order_update.proto`: Order status change notifications
- `event_position_update.proto`: Position change notifications
- `event_trade.proto`: Executed trade details
- `event_account_update.proto`: Account balance and margin updates
- `event_option_greeks.proto`: Options pricing data
- `event_system.proto`: System-level notifications

### Handler Messages
- `handler_init.proto`: Strategy initialization request/response
- `handler_process_event.proto`: Event processing request
- `handler_shutdown.proto`: Graceful shutdown request/response

### Common Types
- `strategy_common.proto`: Shared message types and enums

## Usage

Implement the `TektiiStrategy` service to create a trading strategy that can:
1. Connect to any supported broker through Tektii's broker adapter layer
2. Receive real-time or historical market data
3. Execute trades with comprehensive risk management
4. Run in production or backtesting environments without code changes

## Integration

This protocol is designed to work seamlessly with:
- **tektii-strategy-sdk-python**: Python SDK for strategy development
- **tektii-engine**: Backtesting and simulation engine
- **tektii-broker-adapters**: Connectors for various brokers (Interactive Brokers, Alpaca, etc.)

For implementation examples and best practices, see the Tektii Strategy SDK documentation.