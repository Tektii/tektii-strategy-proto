# Broker-Based Instrument Resolution

## Overview

The Tektii Strategy Protocol uses a **broker-based approach** for instrument identification. The Tektii platform maintains a central directory that maps the combination of `Broker` enum + `symbol` to the correct instrument and market data.

## Architecture

### Simple Design
```
Strategy → (Broker enum, symbol) → Tektii Platform → Broker API
                                           ↓
                                    Instrument Directory
```

### Key Concepts

1. **Broker Enum**: Identifies which broker/exchange to trade through
   - `BROKER_BACKTESTING` - Tektii's backtesting environment
   - `BROKER_ALPACA` - Alpaca trading platform
   - `BROKER_INTERACTIVE_BROKERS` - Interactive Brokers
   - `BROKER_BINANCE` - Binance cryptocurrency exchange
2. **Symbol**: The instrument identifier as used by that specific broker
3. **Tektii Directory**: Central mapping service that handles all instrument resolution

## Implementation

### For Strategy Developers

```python
# Trading with a specific broker
order = PlaceOrderRequest(
    broker=Broker.BROKER_ALPACA,
    symbol="AAPL",  # Alpaca's symbol for Apple
    side=OrderSide.BUY,
    quantity=100,
    # ... other fields
)

# Trading the same instrument on different brokers
orders = [
    PlaceOrderRequest(
        broker=Broker.BROKER_ALPACA, 
        symbol="AAPL",
        # ...
    ),
    PlaceOrderRequest(
        broker=Broker.BROKER_INTERACTIVE_BROKERS,
        symbol="AAPL",  # IB might use same symbol
        # ...
    ),
    PlaceOrderRequest(
        broker=Broker.BROKER_BINANCE,
        symbol="BTCUSDT",  # Binance format for BTC/USDT
        # ...
    )
]
```

### Receiving Events

```python
def process_event(event: ProcessEventRequest):
    # Event includes broker enum to identify source
    if event.broker == Broker.BROKER_ALPACA:
        # Handle Alpaca-specific logic if needed
        pass
    
    # Most strategies can ignore broker and just use the data
    if event.tick_data:
        handle_tick(event.tick_data)
```

## Benefits

1. **Simplicity**: No complex instrument definitions needed
2. **Flexibility**: Each broker's native symbols work directly
3. **Scalability**: Easy to add new brokers without protocol changes
4. **Reliability**: Tektii platform handles all mapping complexity

## Multi-Broker Strategies

### Example: Arbitrage Strategy
```python
class ArbitrageStrategy:
    def process_event(self, event: ProcessEventRequest):
        # Track prices from multiple brokers
        self.prices[event.broker] = event.tick_data.last
        
        # Find arbitrage opportunities
        if self.has_arbitrage_opportunity():
            # Buy on cheaper broker
            self.place_order(
                broker=Broker.BROKER_BINANCE,
                symbol="BTCUSDT",
                side=OrderSide.BUY
            )
            # Sell on expensive broker (when more brokers are added)
            # self.place_order(
            #     broker=Broker.BROKER_COINBASE,
            #     symbol="BTC-USD",
            #     side=OrderSide.SELL
            # )
```

### Example: Best Execution Strategy
```python
def place_order_best_execution(symbol_map: dict, quantity: float):
    # Get quotes from multiple brokers
    quotes = {}
    for broker, symbol in symbol_map.items():
        quote = get_quote(broker, symbol)
        quotes[broker] = quote
    
    # Choose best broker
    best_broker = min(quotes, key=lambda p: quotes[p].ask)
    
    # Place order with best broker
    return PlaceOrderRequest(
        broker=best_broker,
        symbol=symbol_map[best_broker],
        # ...
    )

# Usage
place_order_best_execution({
    Broker.BROKER_ALPACA: "AAPL",
    Broker.BROKER_INTERACTIVE_BROKERS: "AAPL",
    # More brokers can be added as the enum expands
}, 100)
```

## Broker Examples

### Currently Supported Brokers

#### BROKER_ALPACA (Equities)
- Symbol examples: `AAPL`, `MSFT`, `GOOGL`
- Asset focus: US equities and ETFs

#### BROKER_INTERACTIVE_BROKERS (Multi-asset)
- Equity symbols: `AAPL`, `MSFT`, `GOOGL`
- Forex symbols: `EUR.USD`, `GBP.JPY`
- Futures symbols: `ESZ23`, `CLZ23`

#### BROKER_BINANCE (Crypto)
- Symbol examples: `BTCUSDT`, `ETHUSDT`, `BNBUSDT`
- Format: Base asset + Quote asset (no separators)

#### BROKER_BACKTESTING (All assets)
- Uses Tektii's standardized symbol format
- Supports all asset classes for historical simulation

## Best Practices

1. **Use Broker's Native Symbols**: Don't try to translate symbols yourself
2. **Store Broker Context**: Keep track of which broker each position/order is with
3. **Handle Broker Differences**: Each broker may have different:
   - Minimum order sizes
   - Tick sizes
   - Trading hours
   - Fee structures

## Error Handling

```python
try:
    response = place_order(PlaceOrderRequest(
        broker=Broker.BROKER_ALPACA,
        symbol="INVALID",
        # ...
    ))
except Exception as e:
    if e.reject_code == RejectCode.INVALID_SYMBOL:
        # Symbol not found for this broker
        log.error(f"Symbol INVALID not found on Alpaca")
```

## Future Extensibility

The broker-based approach allows easy extension:
- New brokers can be added by extending the Broker enum
- Broker-specific features can be added via metadata
- Cross-broker features work naturally
- Type-safe broker identification with enum values

## Summary

The broker-based approach keeps the protocol simple while enabling sophisticated multi-broker strategies. The Tektii platform handles all the complexity of instrument mapping, letting strategies focus on trading logic.