# Protocol Design Decisions

This document captures key design decisions made for the Tektii Strategy Protocol, particularly around naming conventions and entity modeling for the broker-agnostic trading interface.

## Recent Changes Summary

### 1. Trade Entity Addition
**Decision**: Added a new `Trade` message to represent individual trades/deals separately from positions.

**Rationale**:
- **Netting accounts** (most US equity brokers): Trades immediately aggregate into positions
- **Hedging accounts** (Forex/CFDs): Multiple trades can exist independently for the same symbol
- Enables strategies to work with both account types using the same protocol

**Implementation**:
- Added `Trade` message to `broker/v1/broker_common.proto`
- Added `trades` map to `GetStateResponse`
- Added `include_trades` flag to `GetStateRequest`

### 2. Event Naming Consistency
**Decision**: Renamed events for consistency across the protocol.

**Changes**:
- Added `TradeUpdateEvent` (updates to existing trades)
- Kept `AccountUpdateEvent`, `OrderUpdateEvent`, `PositionUpdateEvent` as is

**Rationale**:
- Clear distinction between execution events and update events
- Consistent `*UpdateEvent` naming pattern for state changes
- `TradeUpdateEvent` = changes to existing trades (P&L updates, partial closes)

### 3. RPC Naming Conventions

#### ModifyTradeProtection (Kept)
**Alternative considered**: `UpdateTrade`

**Decision**: Keep `ModifyTradeProtection`

**Rationale**:
- "Trade protection" specifically refers to stop loss/take profit orders in industry terminology
- `UpdateTrade` is ambiguous - could mean updating trade details, status, or metadata
- Follows the established `Modify*` verb pattern
- Self-documenting and unambiguous

#### ClosePosition (Kept)
**Alternative considered**: `CloseTrade`

**Decision**: Keep `ClosePosition` with enhanced parameters for trade-specific closing

**Rationale**:
- "Position" is the industry standard term across equities, futures, and forex
- FIX Protocol and major brokers (IB, Alpaca) use position-based terminology
- Enhanced with `trade_ids` parameter to support hedging accounts
- Single RPC handles both position-level and trade-level closing

### 4. Market Data Terminology

#### Candle (Kept)
**Alternative considered**: `Bar`

**Decision**: Use `Candle` for OHLCV data

**Rationale**:
- "Candle" specifically implies OHLCV structure with body and wicks
- "Bar" is more generic and could refer to simple bar charts
- Modern platforms trending toward "candle" terminology
- More universally understood across different markets

## Entity Design Philosophy

### Signed Quantities vs Side Enums

**Design Decision**: Intentional asymmetry in quantity representation

| Entity Type   | Representation                | Example      |
| ------------- | ----------------------------- | ------------ |
| **Orders**    | OrderSide + positive quantity | BUY 100      |
| **Trades**    | OrderSide + positive quantity | SELL 50      |
| **Positions** | Signed quantity               | -150 (short) |

**Rationale**:

1. **Transactional Entities** (Orders, Trades):
   - Represent actions: "I want to BUY 100 shares"
   - Match trader mental models and speech patterns
   - Align with FIX protocol and broker API conventions
   - Industry standard for order placement

2. **State Entities** (Positions):
   - Represent net exposure: +100 (long) or -50 (short)
   - Enable simple mathematical operations: `total = pos1 + pos2`
   - Natural for risk calculations and portfolio aggregation
   - Handle zero positions cleanly (no ambiguous "side")

This asymmetry is a **feature, not a bug** - it reflects different semantic purposes and optimizes for both human understanding and computational efficiency.

## Key Design Principles

### 1. Broker Agnostic
All entities and RPCs designed to work across different broker types:
- Interactive Brokers
- Alpaca
- Binance
- Tektii Backtesting Engine

### 2. Account Type Flexibility
Protocol supports both:
- **Netting accounts**: Positions are aggregated
- **Hedging accounts**: Individual trades tracked separately

### 3. Industry Alignment
- Follow FIX protocol conventions where applicable
- Use terminology familiar to professional traders
- Maintain compatibility with major broker APIs

### 4. Semantic Clarity
- RPC names clearly indicate their specific function
- Event types distinguish between executions and updates
- Entity naming reflects industry-standard terminology

### 5. Mathematical Efficiency
- Position representation optimized for portfolio calculations
- Risk metrics can be computed efficiently
- Natural aggregation of exposures across instruments

## Implementation Guidelines

### For Strategy Developers
- Use position quantities directly in calculations (they're already signed)
- Check account type to determine if individual trades are available

### For Broker Adapter Implementers
- Map broker-specific position representations to signed quantities
- Populate trade data only for hedging accounts
- Translate broker events to appropriate event types

### For the Backtesting Engine
- Simulate both netting and hedging account behaviors
- Generate appropriate events based on account configuration
- Maintain trade-level granularity when required

## Future Considerations

### Potential Enhancements
1. Add `PositionSide` enum if explicit side tracking becomes necessary
2. Consider `TradeClosingStrategy` enum for FIFO/LIFO/specific selection
3. Extend `Trade` entity with additional broker-specific fields as needed

### Backward Compatibility
All changes maintain backward compatibility:
- New fields added with higher field numbers
- Optional fields for enhanced functionality
- Existing RPCs enhanced rather than replaced