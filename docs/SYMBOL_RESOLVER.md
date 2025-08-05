# Provider-Based Instrument Resolution

## Overview

The Tektii Strategy Protocol uses a **provider-based approach** for instrument identification. The Tektii platform maintains a central directory that maps the combination of `Provider` enum + `symbol` to the correct instrument and market data.

## Architecture

### Simple Design
```
Strategy → (Provider enum, symbol) → Tektii Platform → Provider API
                                           ↓
                                    Instrument Directory
```

### Key Concepts

1. **Provider Enum**: Identifies which broker/exchange to trade through
   - `PROVIDER_BACKTESTING` - Tektii's backtesting environment
   - `PROVIDER_ALPACA` - Alpaca trading platform
   - `PROVIDER_INTERACTIVE_BROKERS` - Interactive Brokers
   - `PROVIDER_BINANCE` - Binance cryptocurrency exchange
2. **Symbol**: The instrument identifier as used by that specific provider
3. **Tektii Directory**: Central mapping service that handles all instrument resolution

## Implementation

### For Strategy Developers

```python
# Trading with a specific provider
order = PlaceOrderRequest(
    provider=Provider.PROVIDER_ALPACA,
    symbol="AAPL",  # Alpaca's symbol for Apple
    side=OrderSide.BUY,
    quantity=100,
    # ... other fields
)

# Trading the same instrument on different providers
orders = [
    PlaceOrderRequest(
        provider=Provider.PROVIDER_ALPACA, 
        symbol="AAPL",
        # ...
    ),
    PlaceOrderRequest(
        provider=Provider.PROVIDER_INTERACTIVE_BROKERS,
        symbol="AAPL",  # IB might use same symbol
        # ...
    ),
    PlaceOrderRequest(
        provider=Provider.PROVIDER_BINANCE,
        symbol="BTCUSDT",  # Binance format for BTC/USDT
        # ...
    )
]
```

### Receiving Events

```python
def process_event(event: ProcessEventRequest):
    # Event includes provider enum to identify source
    if event.provider == Provider.PROVIDER_ALPACA:
        # Handle Alpaca-specific logic if needed
        pass
    
    # Most strategies can ignore provider and just use the data
    if event.tick_data:
        handle_tick(event.tick_data)
```

## Benefits

1. **Simplicity**: No complex instrument definitions needed
2. **Flexibility**: Each provider's native symbols work directly
3. **Scalability**: Easy to add new providers without protocol changes
4. **Reliability**: Tektii platform handles all mapping complexity

## Multi-Provider Strategies

### Example: Arbitrage Strategy
```python
class ArbitrageStrategy:
    def process_event(self, event: ProcessEventRequest):
        # Track prices from multiple providers
        self.prices[event.provider] = event.tick_data.last
        
        # Find arbitrage opportunities
        if self.has_arbitrage_opportunity():
            # Buy on cheaper provider
            self.place_order(
                provider=Provider.PROVIDER_BINANCE,
                symbol="BTCUSDT",
                side=OrderSide.BUY
            )
            # Sell on expensive provider (when more providers are added)
            # self.place_order(
            #     provider=Provider.PROVIDER_COINBASE,
            #     symbol="BTC-USD",
            #     side=OrderSide.SELL
            # )
```

### Example: Best Execution Strategy
```python
def place_order_best_execution(symbol_map: dict, quantity: float):
    # Get quotes from multiple providers
    quotes = {}
    for provider, symbol in symbol_map.items():
        quote = get_quote(provider, symbol)
        quotes[provider] = quote
    
    # Choose best provider
    best_provider = min(quotes, key=lambda p: quotes[p].ask)
    
    # Place order with best provider
    return PlaceOrderRequest(
        provider=best_provider,
        symbol=symbol_map[best_provider],
        # ...
    )

# Usage
place_order_best_execution({
    Provider.PROVIDER_ALPACA: "AAPL",
    Provider.PROVIDER_INTERACTIVE_BROKERS: "AAPL",
    # More providers can be added as the enum expands
}, 100)
```

## Provider Examples

### Currently Supported Providers

#### PROVIDER_ALPACA (Equities)
- Symbol examples: `AAPL`, `MSFT`, `GOOGL`
- Asset focus: US equities and ETFs

#### PROVIDER_INTERACTIVE_BROKERS (Multi-asset)
- Equity symbols: `AAPL`, `MSFT`, `GOOGL`
- Forex symbols: `EUR.USD`, `GBP.JPY`
- Futures symbols: `ESZ23`, `CLZ23`

#### PROVIDER_BINANCE (Crypto)
- Symbol examples: `BTCUSDT`, `ETHUSDT`, `BNBUSDT`
- Format: Base asset + Quote asset (no separators)

#### PROVIDER_BACKTESTING (All assets)
- Uses Tektii's standardized symbol format
- Supports all asset classes for historical simulation

## Best Practices

1. **Use Provider's Native Symbols**: Don't try to translate symbols yourself
2. **Store Provider Context**: Keep track of which provider each position/order is with
3. **Handle Provider Differences**: Each provider may have different:
   - Minimum order sizes
   - Tick sizes
   - Trading hours
   - Fee structures

## Error Handling

```python
try:
    response = place_order(PlaceOrderRequest(
        provider=Provider.PROVIDER_ALPACA,
        symbol="INVALID",
        # ...
    ))
except Exception as e:
    if e.reject_code == RejectCode.INVALID_SYMBOL:
        # Symbol not found for this provider
        log.error(f"Symbol INVALID not found on Alpaca")
```

## Future Extensibility

The provider-based approach allows easy extension:
- New providers can be added by extending the Provider enum
- Provider-specific features can be added via metadata
- Cross-provider features work naturally
- Type-safe provider identification with enum values

## Summary

The provider-based approach keeps the protocol simple while enabling sophisticated multi-provider strategies. The Tektii platform handles all the complexity of instrument mapping, letting strategies focus on trading logic.