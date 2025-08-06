# Tektii Broker Protocol

This module defines the gRPC service interface for broker adapters in the Tektii platform.

## Overview

The Broker Protocol provides a standardized interface that broker adapters implement to:
- Connect to trading strategies via the Strategy Protocol
- Translate generic trading commands to broker-specific APIs
- Normalize broker events into standard event types
- Handle broker-specific authentication and connection management

## Architecture

The module implements the broker-side interface that complements the Strategy Protocol:

- **Order Handlers**: Process order-related requests from strategies
- **Query Handlers**: Provide market data and account information
- **Event Generation**: Convert broker-specific events to standard format

## Key Components

### Service Definition
- `broker_service.proto`: Main gRPC service definition for broker operations

### Handler Messages
- `handler_place_order.proto`: Order placement with validation and risk checks
- `handler_cancel_order.proto`: Order cancellation requests
- `handler_modify_order.proto`: Order modification with validation
- `handler_close_position.proto`: Position closing operations
- `handler_modify_trade_protection.proto`: Stop loss/take profit management
- `handler_validate_order.proto`: Pre-trade validation without execution
- `handler_get_state.proto`: Current positions, orders, and account state
- `handler_get_historical_data.proto`: Historical market data queries
- `handler_get_market_depth.proto`: Order book and market depth
- `handler_get_risk_metrics.proto`: Portfolio risk calculations

### Common Types
- `broker_common.proto`: Shared message types and enums for broker operations

## Implementation

Broker adapters implement this protocol to:
1. Receive commands from strategies through standardized RPCs
2. Translate generic orders to broker-specific API calls
3. Handle broker authentication and session management
4. Convert broker events to standard event formats
5. Provide consistent error handling and validation

## Supported Brokers

This protocol is designed to support various broker types:
- **Traditional Brokers**: Interactive Brokers, TD Ameritrade
- **Crypto Exchanges**: Binance, Coinbase
- **Modern APIs**: Alpaca, Tradier
- **Backtesting**: Tektii simulation engine

## Benefits

- **Broker Agnostic**: Strategies work with any broker without modification
- **Consistent Interface**: Same API regardless of underlying broker
- **Error Handling**: Standardized error codes and validation
- **Risk Management**: Built-in pre-trade checks and portfolio limits

For implementation guidelines and broker-specific considerations, see the Tektii Broker Adapter documentation.