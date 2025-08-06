# Tektii Strategy Proto Implementation Roadmap

## Overview

This roadmap outlines the implementation plan for the Tektii Strategy Protocol Buffer specification, prioritizing forex and crypto trading for MVP with extensibility for future asset classes. The approach emphasizes backward compatibility and non-breaking changes.

## Guiding Principles

1. **No Breaking Changes**: All additions must be backward compatible
2. **Asset-First Design**: Start with forex/crypto, design for extensibility
3. **Broker Compatibility**: Ensure each feature works with target brokers
4. **Developer Experience**: Maintain clarity and simplicity
5. **Production Readiness**: Each phase must be deployable

---

## Phase 0: Foundation Fixes (MVP Prerequisites)
**Timeline**: 2 weeks  
**Goal**: Address critical technical issues before MVP

### Feature 0.1: Precision-Safe Price Representation ✅ COMPLETED

**Background**: Current `double` type causes precision issues in financial calculations, critical for crypto (8+ decimals) and forex pip calculations.

**Implementation**:
```proto
// Add to common.proto - backward compatible addition
message PreciseDecimal {
  int64 value = 1;      // Scaled integer value
  int32 scale = 2;      // Number of decimal places
  // Example: 1.23456 = {value: 123456, scale: 5}
}
```

**Acceptance Criteria**:
- [x] PreciseDecimal message defined in common.proto ✅ Added to both broker/common.proto and strategy/common.proto
- [x] Documentation on precision handling ✅ Created comprehensive PRECISION_HANDLING.md in docs/
- [x] Validation that scale doesn't exceed broker limits ✅ Documented scale limits per asset type
- [x] Remove existing double fields ✅ Replaced 127 double fields across all proto files

**Completion Notes**:
- Implementation completed without backward compatibility concerns as requested
- PreciseDecimal message added to both broker and strategy common.proto files
- Successfully replaced all monetary double fields (prices, quantities, values, P&L, margins)
- Created detailed precision handling guide with validation rules, implementation examples, and broker-specific considerations
- No double fields remain for monetary values in the codebase

**Out of Scope**:
- Arbitrary precision arithmetic

**Watch Out For**:
- Different precision requirements per asset (forex: 5, crypto: 8+)
- Broker-specific precision limits
- Conversion edge cases

### Feature 0.2: Currency and Asset Type Foundation ✅ COMPLETED

**Background**: Essential for multi-currency trading in forex and crypto pairs.

**Original Design**:
```proto
enum AssetClass {
  ASSET_CLASS_UNSPECIFIED = 0;
  ASSET_CLASS_CRYPTO = 1;
  ASSET_CLASS_FOREX = 2;
  ASSET_CLASS_EQUITY = 3;      // Future
  ASSET_CLASS_OPTION = 4;      // Future
  ASSET_CLASS_FUTURE = 5;      // Future
  ASSET_CLASS_COMMODITY = 6;   // Future
}

message CurrencyPair {
  string base_currency = 1;    // BTC in BTC/USD
  string quote_currency = 2;   // USD in BTC/USD
  AssetClass asset_class = 3;
}
```

**Actual Implementation**: ✅ PIVOTED TO BROKER-BASED APPROACH

After review, we pivoted from complex currency pairs to a simpler broker-based approach:

```proto
// Added to all relevant messages
Broker broker = N;  // "alpaca", "binance", "oanda", etc.

// AssetClass enum still added for basic classification
enum AssetClass {
  ASSET_CLASS_UNSPECIFIED = 0;
  ASSET_CLASS_CRYPTO = 1;
  ASSET_CLASS_FOREX = 2;
  ASSET_CLASS_EQUITY = 3;
  ASSET_CLASS_OPTION = 4;
  ASSET_CLASS_FUTURE = 5;
  ASSET_CLASS_COMMODITY = 6;
}
```

**Acceptance Criteria**:
- [x] AssetClass enum with reserved ranges ✅ Added to both common.proto files
- [x] ~~CurrencyPair message for forex/crypto~~ ❌ Removed - too specific
- [x] Symbol resolver documentation ✅ Created broker-based resolution docs
- [x] Backward compatible with single symbol field ✅ Symbol field unchanged
- [x] Broker identification support ✅ Added Broker enum to key messages

**Key Decision**: Instead of modeling complex instrument types, we rely on:
1. Broker ID + Symbol combination
2. Tektii platform's instrument directory for mapping
3. Simple, generic approach that works for all asset types

**Implementation Notes**:
- Added `Broker` enum field to: Position, Order, PlaceOrderRequest, ProcessEventRequest
- Removed overly specific CurrencyPair and InstrumentIdentifier messages
- Created comprehensive documentation on broker-based approach
- Maintains full backward compatibility

**Out of Scope**:
- Complex instrument definitions
- Options/futures specifications

**Watch Out For**:
- Symbol format differences (BTCUSD vs BTC/USD vs BTC-USD)
- Stablecoin classifications
- Cross-exchange symbol mapping

---

## Phase 1: MVP - Basic Forex & Crypto Trading
**Timeline**: 4 weeks  
**Goal**: Minimum viable trading for forex and crypto

### Feature 1.1: Enhanced Symbol Specification

**Background**: Forex uses standard pairs (EUR/USD), crypto uses varied formats (BTC/USDT, BTC-USD).

**⚠️ UPDATED APPROACH**: Based on Feature 0.2 implementation, we now use broker-based identification instead of complex instrument definitions.

**Implementation**:
```proto
// SIMPLIFIED: Just use Broker enum + symbol
// No need for InstrumentIdentifier or CurrencyPair
message Order {
  string symbol = 1;        // Broker's native symbol
  Broker broker = 2;   // Which broker to use
  // ... other fields
}
```

**Acceptance Criteria**:
- [ ] ~~Support both legacy symbol and new structured format~~ → Use Broker enum instead
- [ ] ~~Broker mapping for symbol translation~~ → Handled by Tektii platform
- [ ] Documentation for symbol formats per broker
- [ ] ~~Validation for supported asset classes~~ → Platform validates broker+symbol

**Out of Scope**:
- Complex derivatives (options on futures)
- Multi-leg instrument definitions
- Symbol translation in protocol

**Watch Out For**:
- Broker-specific symbol formats (handled by platform)
- Each broker must be used with its native symbols
- No cross-broker symbol translation in strategy

### Feature 1.2: Crypto-Specific Order Types

**Background**: Crypto exchanges support maker/taker distinctions and post-only orders.

**Implementation**:
```proto
enum OrderType {
  ORDER_TYPE_UNSPECIFIED = 0;
  ORDER_TYPE_MARKET = 1;
  ORDER_TYPE_LIMIT = 2;
  ORDER_TYPE_STOP = 3;
  ORDER_TYPE_STOP_LIMIT = 4;
  ORDER_TYPE_LIMIT_MAKER = 5;  // Post-only (crypto)
}

message OrderFees {
  PreciseDecimal maker_fee = 1;
  PreciseDecimal taker_fee = 2;
  string fee_currency = 3;
  PreciseDecimal estimated_fee = 4;
}
```

**Acceptance Criteria**:
- [ ] Post-only/maker order support
- [ ] Fee structure in order responses
- [ ] Maker/taker fee distinction
- [ ] Fee currency specification

**Out of Scope**:
- Complex fee tiers
- Exchange-specific order types
- Rebate handling

**Watch Out For**:
- Not all exchanges support post-only
- Fee calculation differences
- Network fees vs trading fees

### Feature 1.3: 24/7 Market Support

**Background**: Crypto trades 24/7, forex trades 24/5 with different sessions.

**Implementation**:
```proto
message MarketHours {
  bool is_24_7 = 1;
  repeated TradingSession sessions = 2;
  string timezone = 3;  // IANA timezone
}

message TradingSession {
  string name = 1;      // "Sydney", "London", "New York"
  int64 open_time = 2;  // Seconds since midnight
  int64 close_time = 3; // Seconds since midnight
  repeated int32 trading_days = 4; // 1=Monday, 7=Sunday
}
```

**Acceptance Criteria**:
- [ ] Market hours in instrument metadata
- [ ] Session-aware order validation
- [ ] Timezone handling documentation
- [ ] Holiday calendar support structure

**Out of Scope**:
- Complex holiday rules
- Partial trading days
- Pre/post market sessions

**Watch Out For**:
- Daylight saving transitions
- Crypto maintenance windows
- Forex weekend gaps

### Feature 1.4: Basic Position Tracking Enhancement

**Background**: Forex/crypto often use base currency position sizes.

**⚠️ UPDATED APPROACH**: Based on Feature 0.2, currency-specific fields are handled by the platform, not the protocol.

**Implementation**:
```proto
message Position {
  // Existing fields maintained...
  string symbol = 1;
  PreciseDecimal quantity = 2;
  // ... standard fields ...
  
  // NEW: Broker identification
  Broker broker = 8;  // Which broker holds this position
  
  // Currency conversions handled by platform based on broker+symbol
}
```

**Acceptance Criteria**:
- [ ] ~~Base/quote currency position tracking~~ → Platform handles via broker+symbol
- [ ] Multi-currency P&L calculation → Platform responsibility
- [ ] ~~Conversion rate tracking~~ → Platform maintains FX rates
- [ ] Broker identification for positions
- [ ] Backward compatibility maintained

**Out of Scope**:
- Complex currency hedging
- Cross-margin positions
- Portfolio-level currency exposure
- Currency fields in protocol

**Watch Out For**:
- Broker must be tracked for each position
- Platform handles all currency conversions
- Symbol interpretation depends on broker

---

## Phase 2: Enhanced Trading Features
**Timeline**: 3 weeks  
**Goal**: Professional trading features for forex/crypto

### Feature 2.1: Advanced Order Types

**Background**: Professional traders need trailing stops and OCO orders.

**Implementation**:
```proto
enum OrderType {
  // ... existing types ...
  ORDER_TYPE_TRAILING_STOP = 6;
  ORDER_TYPE_OCO = 7;  // One-Cancels-Other
}

message TrailingStopConfig {
  oneof trail_spec {
    PreciseDecimal trail_amount = 1;   // Fixed distance
    double trail_percent = 2;          // Percentage
  }
  PreciseDecimal activation_price = 3; // Optional activation
}

message OCOConfig {
  string linked_order_id = 1;
  OCOLinkType link_type = 2;
}
```

**Acceptance Criteria**:
- [ ] Trailing stop implementation
- [ ] OCO order linking
- [ ] Server-side trail calculation option
- [ ] Validation for supported order types per broker

**Out of Scope**:
- Algorithmic orders (TWAP/VWAP)
- Conditional orders
- Complex bracket strategies

**Watch Out For**:
- Not all brokers support all types
- Trail calculation differences
- OCO partial fill handling

### Feature 2.2: Market Depth & Order Book

**Background**: Crypto trading requires order book visibility.

**Implementation**:
```proto
message MarketDepth {
  string symbol = 1;
  repeated PriceLevel bids = 2;
  repeated PriceLevel asks = 3;
  int64 timestamp_us = 4;
  int32 depth = 5;  // Number of levels
  Broker broker = 6;  // Source of market data
}

message PriceLevel {
  PreciseDecimal price = 1;
  PreciseDecimal quantity = 2;
  int32 order_count = 3;  // Number of orders at this level
}
```

**Acceptance Criteria**:
- [ ] Configurable depth levels
- [ ] Aggregated order book support
- [ ] Real-time updates via events
- [ ] Snapshot and delta modes

**Out of Scope**:
- Full order book reconstruction
- Individual order details
- Market-by-order data

**Watch Out For**:
- Data volume for deep books
- Update frequency limits
- Cross-exchange aggregation

### Feature 2.3: Leverage & Margin Trading

**Background**: Forex and crypto margin trading are fundamental.

**Implementation**:
```proto
message LeverageConfig {
  double max_leverage = 1;
  double current_leverage = 2;
  map<string, double> symbol_leverage = 3;  // Per-symbol limits
}

message MarginRequirement {
  PreciseDecimal initial_margin = 1;
  PreciseDecimal maintenance_margin = 2;
  PreciseDecimal margin_call_level = 3;
  PreciseDecimal liquidation_level = 4;
  string margin_currency = 5;
}
```

**Acceptance Criteria**:
- [ ] Leverage configuration per account/symbol
- [ ] Margin requirement calculations
- [ ] Margin call notifications
- [ ] Cross vs isolated margin support

**Out of Scope**:
- Portfolio margining
- Complex margin algorithms
- Cross-currency margin

**Watch Out For**:
- Regulatory leverage limits
- Dynamic margin requirements
- Liquidation engine differences

---

## Phase 3: Risk & Compliance
**Timeline**: 3 weeks  
**Goal**: Production-ready risk management

### Feature 3.1: Pre-Trade Risk Checks

**Background**: Essential for preventing trading errors and compliance.

**Implementation**:
```proto
message RiskLimits {
  // Position limits
  map<string, PreciseDecimal> max_position_size = 1;
  map<string, PreciseDecimal> max_order_size = 2;
  
  // Value limits
  PreciseDecimal max_daily_loss = 3;
  PreciseDecimal max_open_orders_value = 4;
  
  // Rate limits
  int32 max_orders_per_minute = 5;
  int32 max_orders_per_day = 6;
  
  // Restricted lists
  repeated string restricted_symbols = 7;
  repeated string long_only_symbols = 8;
}
```

**Acceptance Criteria**:
- [ ] Pre-trade validation against limits
- [ ] Real-time limit tracking
- [ ] Limit breach notifications
- [ ] Override mechanisms with audit

**Out of Scope**:
- Complex conditional limits
- Machine learning risk models
- Cross-account limits

**Watch Out For**:
- Performance impact of checks
- Limit update latency
- Emergency override procedures

### Feature 3.2: Settlement & Funding

**Background**: Crypto funding rates and forex settlement are critical.

**Implementation**:
```proto
message FundingInfo {
  double funding_rate = 1;
  int64 next_funding_time = 2;
  PreciseDecimal funding_payment = 3;
}

message SettlementInfo {
  string settlement_currency = 1;
  int64 settlement_date = 2;
  enum SettlementType {
    SETTLEMENT_TYPE_UNSPECIFIED = 0;
    SETTLEMENT_TYPE_CASH = 1;
    SETTLEMENT_TYPE_PHYSICAL = 2;
  }
  SettlementType settlement_type = 3;
}
```

**Acceptance Criteria**:
- [ ] Funding rate tracking for perpetuals
- [ ] Settlement date calculations
- [ ] T+N settlement support
- [ ] Funding payment history

**Out of Scope**:
- Complex settlement netting
- Multi-currency settlement
- Delivery logistics

**Watch Out For**:
- Weekend/holiday settlement
- Funding rate calculation methods
- Time zone considerations

---

## Phase 4: Advanced Features
**Timeline**: 4 weeks  
**Goal**: Differentiated features for professional traders

### Feature 4.1: Multi-Account Support

**Background**: Professional traders manage multiple accounts/subaccounts.

**⚠️ BROKER CONSIDERATION**: Multi-account support must work across brokers.

**Implementation**:
```proto
message AccountSelector {
  string primary_account_id = 1;
  repeated string sub_account_ids = 2;
  AccountAggregation aggregation = 3;
  Broker broker = 4;  // Broker context for accounts
}

enum AccountAggregation {
  ACCOUNT_AGGREGATION_NONE = 0;
  ACCOUNT_AGGREGATION_SUM = 1;
  ACCOUNT_AGGREGATION_MASTER = 2;
}
```

**Acceptance Criteria**:
- [ ] Multi-account order routing
- [ ] Aggregated position views
- [ ] Account-specific risk limits
- [ ] Cross-account margin (where supported)

**Out of Scope**:
- Complex allocation algorithms
- Prime brokerage features
- White-label support

**Watch Out For**:
- Regulatory restrictions
- Broker account limits
- Performance with many accounts

### Feature 4.2: Advanced Analytics

**Background**: Professional traders need real-time analytics.

**Implementation**:
```proto
message PerformanceMetrics {
  // Returns
  double total_return = 1;
  double daily_return = 2;
  double monthly_return = 3;
  
  // Risk metrics
  double sharpe_ratio = 4;
  double sortino_ratio = 5;
  double max_drawdown = 6;
  
  // Trading metrics
  double win_rate = 7;
  double profit_factor = 8;
  double avg_win_loss_ratio = 9;
  
  // Time-based
  map<string, double> returns_by_period = 10;
}
```

**Acceptance Criteria**:
- [ ] Real-time metric calculation
- [ ] Historical metric tracking
- [ ] Benchmark comparisons
- [ ] Custom metric support

**Out of Scope**:
- Complex attribution analysis
- Factor models
- Machine learning insights

**Watch Out For**:
- Calculation performance
- Data storage requirements
- Metric standardization

### Feature 4.3: Notification System

**Background**: Real-time alerts for trading events.

**Implementation**:
```proto
message NotificationConfig {
  repeated NotificationRule rules = 1;
  repeated NotificationChannel channels = 2;
}

message NotificationRule {
  string rule_id = 1;
  NotificationTrigger trigger = 2;
  NotificationPriority priority = 3;
  map<string, string> parameters = 4;
}

enum NotificationTrigger {
  NOTIFICATION_TRIGGER_UNSPECIFIED = 0;
  NOTIFICATION_TRIGGER_ORDER_FILL = 1;
  NOTIFICATION_TRIGGER_STOP_LOSS_HIT = 2;
  NOTIFICATION_TRIGGER_MARGIN_CALL = 3;
  NOTIFICATION_TRIGGER_LARGE_LOSS = 4;
  NOTIFICATION_TRIGGER_SYSTEM_ERROR = 5;
}
```

**Acceptance Criteria**:
- [ ] Configurable notification rules
- [ ] Multiple channel support
- [ ] Rate limiting
- [ ] Notification history

**Out of Scope**:
- Complex event processing
- Natural language generation
- Push notification infrastructure

**Watch Out For**:
- Notification storms
- Latency requirements
- Channel reliability

---

## Phase 5: Ecosystem Expansion
**Timeline**: 4 weeks  
**Goal**: Support for additional asset classes

### Feature 5.1: Equity Trading Support

**Background**: Expand beyond forex/crypto to traditional equities.

**⚠️ UPDATED APPROACH**: Broker-based approach eliminates need for asset-specific messages.

**Implementation**:
```proto
// NO NEED for EquityInstrument message
// Just use Broker enum + symbol:
// - broker: BROKER_ALPACA 
// - symbol: "AAPL"
// Platform knows this is Apple Inc. common stock

// AssetClass enum already supports equities:
enum AssetClass {
  // ...
  ASSET_CLASS_EQUITY = 3;
  // ...
}
```

message CorporateAction {
  enum ActionType {
    ACTION_TYPE_DIVIDEND = 0;
    ACTION_TYPE_SPLIT = 1;
    ACTION_TYPE_MERGER = 2;
  }
  ActionType action_type = 1;
  PreciseDecimal adjustment_factor = 2;
  int64 ex_date = 3;
}
```

**Acceptance Criteria**:
- [ ] Equity instrument definitions
- [ ] Market hours/holidays
- [ ] Corporate action handling
- [ ] Regulatory compliance (PDT, etc.)

**Out of Scope**:
- Options on equities
- Complex corporate actions
- Direct market access

**Watch Out For**:
- Settlement differences (T+2)
- Pre/post market trading
- Regulatory requirements

### Feature 5.2: Futures Support

**Background**: Natural progression for institutional traders.

**⚠️ UPDATED APPROACH**: Broker handles contract specifications.

**Implementation**:
```proto
// NO NEED for FuturesContract message
// Just use Broker enum + symbol:
// - broker: BROKER_INTERACTIVE_BROKERS
// - symbol: "ESZ23"  // E-mini S&P Dec 2023
// Platform and broker handle contract specs

message RolloverConfig {
  int32 days_before_expiry = 1;
  RolloverStrategy strategy = 2;
  bool auto_roll = 3;
}
```

**Acceptance Criteria**:
- [ ] Contract specifications
- [ ] Expiry handling
- [ ] Roll-over support
- [ ] Margin calculations

**Out of Scope**:
- Physical delivery
- Complex spread trading
- Options on futures

**Watch Out For**:
- Contract standardization
- Roll-over gaps
- Margin methodology differences

---

## Migration Strategy

### Version Management
```proto
message ProtocolVersion {
  int32 major = 1;  // Breaking changes (should be 0)
  int32 minor = 2;  // New features
  int32 patch = 3;  // Bug fixes
}
```

### Broker-Based Architecture Benefits
The broker-based approach implemented in Feature 0.2 simplifies the entire roadmap:
1. **No complex instrument definitions needed** - Broker + symbol is sufficient
2. **No asset-specific messages** - Generic messages work for all assets
3. **Easier multi-broker support** - Natural part of the design
4. **Simpler protocol evolution** - Fewer breaking changes needed

### Deprecation Process
1. Add new field alongside old
2. Support both for 2 releases
3. Mark old field deprecated
4. Remove after 6 months

### Broker Adapter Strategy
- Feature flags per broker
- Capability discovery API
- Graceful degradation

---

## Product Review Addendum

### Phase 0 - Foundation Fixes
**Product Priority**: CRITICAL  
**User Impact**: Prevents calculation errors that could cost traders money  
**Market Differentiator**: Reliability builds trust  
**Recommendation**: Consider adding user-visible precision indicators

### Phase 1 - MVP
**Product Priority**: CRITICAL  
**User Impact**: Core trading functionality for target markets  
**Market Differentiator**: Clean forex/crypto support  
**Recommendations**:
- Add demo/paper trading mode
- Include basic charting data support
- Consider mobile-specific optimizations

### Phase 2 - Enhanced Trading
**Product Priority**: HIGH  
**User Impact**: Enables professional trading strategies  
**Market Differentiator**: Advanced features attract sophisticated traders  
**Recommendations**:
- Add strategy templates
- Include backtesting hooks
- Consider social/copy trading preparation

### Phase 3 - Risk & Compliance
**Product Priority**: HIGH  
**User Impact**: Protects users and platform  
**Market Differentiator**: Enterprise-ready compliance  
**Recommendations**:
- Add risk education tooltips
- Include risk score visualizations
- Consider gamification of safe trading

### Phase 4 - Advanced Features
**Product Priority**: MEDIUM  
**User Impact**: Power user features  
**Market Differentiator**: Professional trader platform  
**Recommendations**:
- Add API usage analytics
- Include performance leagues
- Consider institutional onboarding

### Phase 5 - Ecosystem Expansion
**Product Priority**: MEDIUM  
**User Impact**: One platform for all trading  
**Market Differentiator**: Multi-asset platform  
**Recommendations**:
- Add asset class education
- Include unified portfolio view
- Consider fractional trading

## Success Metrics

### Technical Metrics
- API latency < 10ms p99
- Zero breaking changes
- 99.99% uptime per service
- < 0.001% calculation errors

### Product Metrics
- Time to first trade < 5 minutes
- Feature adoption > 40%
- User retention > 80% at 30 days
- NPS > 50

### Business Metrics
- Cost per trade < $0.001
- Platform fee capture > 90%
- Multi-asset trader % > 30%
- Enterprise clients > 10

## Risk Register

### Technical Risks
1. **Precision migration**: Data corruption during transition
2. **Broker compatibility**: Feature gaps between brokers
3. **Performance degradation**: Complex risk checks slow orders
4. **Version fragmentation**: Clients on old versions

### Product Risks
1. **Feature complexity**: Users overwhelmed by options
2. **Market fit**: Forex/crypto focus may limit TAM
3. **Competition**: Established players with more features
4. **Regulatory**: Changing requirements per jurisdiction

### Mitigation Strategies
1. Extensive testing infrastructure
2. Broker capability matrix
3. Performance benchmarking
4. Strong deprecation policy
5. Progressive disclosure UI
6. Regular user research
7. Regulatory consultation
8. Agile iteration process