# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **Protocol Buffer definition repository** that provides a **generic trading interface** for Tektii's platform. It defines a provider-agnostic gRPC service interface that enables trading strategies to work across multiple trading providers without modification.

### Architecture Flow
```
User Strategy → gRPC Server (implements this proto) → Provider Adapter → Specific Trading Provider API
```

This abstraction layer allows:
- **Strategies** to be written once and work with any provider
- **Provider Adapters** to translate generic commands to provider-specific APIs
- **Consistent Interface** regardless of underlying broker/exchange

## Essential Commands

Since this is a proto definition repository with no build system, the primary workflow is:

```bash
# View current changes
git status
git diff

# Commit changes following conventional commit format
git add strategy.proto
git commit -m "feat: add new event type for X"
git push
```

## High-Level Architecture

### Service Definition

The repository defines a single gRPC service `TektiiStrategy` with these RPC methods:

1. **Event Processing** (Event-driven interface)
   - `ProcessEvent` - Receives market/trading events for strategy processing (no actions returned)

2. **Order Management** (Synchronous interface with immediate feedback)
   - `PlaceOrder` - Submit orders with immediate acceptance/rejection and risk checks
   - `CancelOrder` - Cancel existing orders with confirmation
   - `ModifyOrder` - Modify order parameters with validation
   - `ValidateOrder` - Pre-trade risk check without placing order
   - `ClosePosition` - Close positions with order creation
   - `ModifyTradeProtection` - Manage stop loss/take profit orders

3. **Lifecycle Management**
   - `Initialize` - Strategy initialization with configuration
   - `Shutdown` - Graceful shutdown

4. **Query Methods** (Pull-based data access)
   - `GetState` - Current positions, orders, and account state
   - `GetHistoricalData` - Historical market data for analysis
   - `GetMarketDepth` - Order book/market depth
   - `GetRiskMetrics` - Portfolio risk calculations

### Event Types (via ProcessEventRequest)

Market Data:
- `TickData` - High-frequency quotes and trades
- `CandleData` - OHLCV aggregated data
- `OptionGreeks` - Options pricing data

Trading Events:
- `OrderUpdateEvent` - Order status changes
- `PositionUpdateEvent` - Position changes
- `TradeEvent` - Executed trades
- `AccountUpdateEvent` - Account balance updates
- `SystemEvent` - System-level notifications


### Order Management (Synchronous RPCs)

Order-related operations now use dedicated synchronous RPC methods that provide:
- **Immediate feedback**: Order acceptance/rejection with reasons
- **Pre-trade risk checks**: Margin, position limits, portfolio impact
- **Request correlation**: Track requests with client-provided IDs
- **Comprehensive error handling**: Typed rejection codes and validation

## Integration Pattern

This proto file serves as the contract between three key components:

1. **User Strategies** (Any Language)
   - Implement the `TektiiStrategy` service
   - Receive events and return actions through this interface
   - Example: tektii-strategy-sdk-python provides base classes

2. **Provider Adapters** (Platform Side)
   - Implement the client side of this protocol
   - Translate generic orders/actions to provider-specific API calls
   - Handle provider-specific event formats and convert to ProcessEventRequest

3. **Tektii Engine** (Backtesting)
   - Acts as a provider adapter for historical simulation
   - Sends market events and processes strategy actions

### Implementation Flow

```
1. Strategy implements TektiiStrategy service (gRPC server)
2. Provider adapter connects as gRPC client
3. Event flow:
   - Provider sends market events → ProcessEvent → Strategy processes internally
   - Strategy calls PlaceOrder/CancelOrder/etc → Provider processes synchronously → Returns result
4. Benefits of hybrid approach:
   - Event-driven for market data (efficient, batched)
   - Synchronous for orders (immediate feedback, error handling)
   - Aligns with industry standards (FIX protocol, major broker APIs)
5. Same strategy code works with:
   - Interactive Brokers
   - Alpaca
   - Binance
   - Tektii Backtesting Engine
   - Any future provider
```

## Proto Design Conventions

- **Timestamps**: Always in microseconds since epoch (`int64 timestamp_us`)
- **Instrument Identifiers**: Use `symbol` field (string) for instrument identification
- **Extensibility**: Include `metadata` maps for custom data
- **Enums**: Always include `UNKNOWN = 0` as first value
- **Nullable Fields**: Use `google.protobuf.wrappers` for optional primitives
- **Field Numbering**: Reserve ranges for future expansion

## Making Changes

When modifying the proto file:

1. **Backward Compatibility**: Only add new fields or messages, never remove or renumber existing ones
2. **Field Numbers**: Continue from the highest existing number in each message
3. **Documentation**: Add clear comments for new fields/messages
4. **Commit Messages**: Use conventional commit format (feat:, fix:, refactor:, etc.)
5. **Provider Neutrality**: Ensure changes remain generic and don't favor specific providers
6. **Testing Impact**: Consider how changes affect:
   - Existing strategy implementations
   - All provider adapters
   - The backtesting engine

### Design Principles

- **Generic Over Specific**: Avoid provider-specific fields or concepts
- **Extensible**: Use metadata maps for provider-specific data when needed
- **Complete**: Ensure the interface supports common trading operations across all provider types