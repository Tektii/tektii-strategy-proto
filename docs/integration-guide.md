# Integration Guide

This guide provides detailed instructions for integrating with the Trading Interface Protocol.

## Table of Contents

- [Overview](#overview)
- [For Strategy Developers](#for-strategy-developers)
- [For Provider Adapter Developers](#for-provider-adapter-developers)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## Overview

The Trading Interface Protocol enables two types of integrations:

1. **Strategy Integration**: Implement the service to create a trading strategy
2. **Provider Integration**: Create an adapter to connect strategies to a specific broker/exchange

## For Strategy Developers

### Step 1: Choose Your Implementation Approach

#### Option A: Use an SDK (Recommended)

Several language-specific SDKs provide base classes and utilities:

- **Python**: `pip install trading-interface-sdk`
- **Go**: `go get github.com/your-org/trading-interface-go`
- **Java**: Add to Maven/Gradle dependencies
- **Rust**: Add to Cargo.toml

#### Option B: Generate from Proto

```bash
# Install buf if not already installed
brew install bufbuild/buf/buf

# Clone this repo or add as dependency
git clone https://github.com/your-org/trading-interface-proto.git

# Generate code
buf generate
```

### Step 2: Implement the Service

#### Python Implementation

```python
from concurrent import futures
import grpc
from trading.v1 import orders_pb2_grpc, orders_pb2, market_data_pb2, common_pb2

class MyStrategy(orders_pb2_grpc.TradingServiceServicer):
    def __init__(self):
        self.positions = {}
        self.pending_orders = {}
        self.config = {}
    
    def Initialize(self, request, context):
        """Initialize strategy with configuration."""
        self.config = dict(request.config)
        print(f"Initialized with symbols: {request.symbols}")
        return orders_pb2.InitResponse(
            success=True,
            capabilities={
                "supports_options": "true",
                "max_positions": "10",
                "strategy_version": "1.0.0"
            }
        )
    
    def ProcessEvent(self, request, context):
        """Handle incoming market/trading events."""
        # Dispatch based on event type
        if request.HasField('tick_data'):
            self._handle_tick(request.tick_data)
        elif request.HasField('bar_data'):
            self._handle_bar(request.bar_data)
        elif request.HasField('order_update'):
            self._handle_order_update(request.order_update)
        
        return orders_pb2.ProcessEventResponse(success=True)
    
    def PlaceOrder(self, request, context):
        """Place a new order with validation."""
        # Validate order parameters
        if request.quantity <= 0:
            return orders_pb2.PlaceOrderResponse(
                accepted=False,
                reject_reason="Invalid quantity",
                reject_code=common_pb2.REJECT_CODE_INVALID_QUANTITY
            )
        
        # Risk checks
        risk_check = self._perform_risk_check(request)
        if not risk_check.passed:
            return orders_pb2.PlaceOrderResponse(
                accepted=False,
                reject_reason=risk_check.reason,
                reject_code=common_pb2.REJECT_CODE_RISK_CHECK_FAILED,
                risk_check=risk_check.result
            )
        
        # Accept order
        order_id = f"ORD_{request.request_id}"
        return orders_pb2.PlaceOrderResponse(
            accepted=True,
            order_id=order_id,
            request_id=request.request_id,
            risk_check=risk_check.result,
            estimated_fill_price=self._estimate_fill_price(request)
        )
    
    def _handle_tick(self, tick):
        """Process tick data."""
        # Implement your tick handling logic
        pass
    
    def _handle_bar(self, bar):
        """Process bar data."""
        # Implement your bar handling logic
        pass
    
    def _perform_risk_check(self, order_request):
        """Perform pre-trade risk checks."""
        # Implement risk checks
        return RiskCheckResult(passed=True)
```

#### Go Implementation

```go
package main

import (
    "context"
    "fmt"
    "log"
    
    pb "github.com/your-org/trading-interface-proto/gen/go/trading/v1"
    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

type Strategy struct {
    pb.UnimplementedTradingServiceServer
    config    map[string]string
    positions map[string]*Position
}

func (s *Strategy) Initialize(ctx context.Context, req *pb.InitRequest) (*pb.InitResponse, error) {
    s.config = req.Config
    log.Printf("Initialized with %d symbols", len(req.Symbols))
    
    return &pb.InitResponse{
        Success: true,
        Capabilities: map[string]string{
            "supports_options": "true",
            "strategy_version": "1.0.0",
        },
    }, nil
}

func (s *Strategy) ProcessEvent(ctx context.Context, req *pb.TradingEvent) (*pb.ProcessEventResponse, error) {
    // Handle different event types
    switch event := req.Event.(type) {
    case *pb.TradingEvent_TickData:
        return s.handleTick(ctx, event.TickData)
    case *pb.TradingEvent_BarData:
        return s.handleBar(ctx, event.BarData)
    case *pb.TradingEvent_OrderUpdate:
        return s.handleOrderUpdate(ctx, event.OrderUpdate)
    }
    
    return &pb.ProcessEventResponse{Success: true}, nil
}

func (s *Strategy) PlaceOrder(ctx context.Context, req *pb.PlaceOrderRequest) (*pb.PlaceOrderResponse, error) {
    // Validate order
    if req.Quantity <= 0 {
        return &pb.PlaceOrderResponse{
            Accepted:     false,
            RejectReason: "Invalid quantity",
            RejectCode:   pb.RejectCode_REJECT_CODE_INVALID_QUANTITY,
        }, nil
    }
    
    // Perform risk checks
    riskCheck := s.performRiskCheck(req)
    if !riskCheck.Passed {
        return &pb.PlaceOrderResponse{
            Accepted:     false,
            RejectReason: riskCheck.Reason,
            RejectCode:   pb.RejectCode_REJECT_CODE_RISK_CHECK_FAILED,
            RiskCheck:    riskCheck.Result,
        }, nil
    }
    
    // Accept order
    orderID := fmt.Sprintf("ORD_%s", req.RequestId)
    return &pb.PlaceOrderResponse{
        Accepted:  true,
        OrderId:   orderID,
        RequestId: req.RequestId,
        RiskCheck: riskCheck.Result,
    }, nil
}
```

### Step 3: Start the gRPC Server

#### Python Server

```python
def serve():
    # Create server with thread pool
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    
    # Add service
    orders_pb2_grpc.add_TradingServiceServicer_to_server(
        MyStrategy(), server
    )
    
    # Listen on port
    port = '50051'
    server.add_insecure_port(f'[::]:{port}')
    
    # Start server
    server.start()
    print(f"Strategy server started on port {port}")
    
    # Keep alive
    try:
        while True:
            time.sleep(86400)
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == '__main__':
    serve()
```

#### Go Server

```go
func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("failed to listen: %v", err)
    }
    
    // Create gRPC server
    s := grpc.NewServer()
    
    // Register service
    pb.RegisterTradingServiceServer(s, &Strategy{
        positions: make(map[string]*Position),
    })
    
    log.Printf("Strategy server listening on %v", lis.Addr())
    
    if err := s.Serve(lis); err != nil {
        log.Fatalf("failed to serve: %v", err)
    }
}
```

## For Provider Adapter Developers

### Step 1: Create gRPC Client

#### Python Client

```python
import grpc
from trading.v1 import orders_pb2_grpc, orders_pb2, market_data_pb2

class ProviderAdapter:
    def __init__(self, strategy_address):
        # Create gRPC channel
        self.channel = grpc.insecure_channel(strategy_address)
        self.stub = orders_pb2_grpc.TradingServiceStub(self.channel)
        
        # Initialize connection
        self._initialize_strategy()
    
    def _initialize_strategy(self):
        """Initialize the connected strategy."""
        request = orders_pb2.InitRequest(
            config={
                "provider": "my_broker",
                "account_type": "margin",
                "base_currency": "USD"
            },
            symbols=["AAPL", "MSFT", "GOOGL"],
            strategy_id="STRAT_001"
        )
        
        response = self.stub.Initialize(request)
        if not response.success:
            raise Exception(f"Strategy initialization failed: {response.message}")
    
    def send_market_data(self, symbol, bid, ask, last):
        """Send tick data to strategy."""
        tick = market_data_pb2.TickData(
            symbol=symbol,
            bid=bid,
            ask=ask,
            last=last,
            tick_type=market_data_pb2.TickData.TICK_TYPE_QUOTE_AND_TRADE
        )
        
        event = orders_pb2.TradingEvent(
            event_id=str(uuid.uuid4()),
            timestamp_us=int(time.time() * 1_000_000),
            tick_data=tick
        )
        
        response = self.stub.ProcessEvent(event)
        return response.success
```

### Step 2: Map Provider Events

```python
class BrokerEventMapper:
    """Maps broker-specific events to protocol events."""
    
    def map_order_status(self, broker_order):
        """Convert broker order to protocol order update."""
        # Map broker status to protocol status
        status_map = {
            "PENDING": common_pb2.ORDER_STATUS_PENDING,
            "WORKING": common_pb2.ORDER_STATUS_ACCEPTED,
            "FILLED": common_pb2.ORDER_STATUS_FILLED,
            "CANCELLED": common_pb2.ORDER_STATUS_CANCELED,
        }
        
        return market_data_pb2.OrderUpdateEvent(
            order_id=broker_order.id,
            symbol=broker_order.symbol,
            status=status_map.get(broker_order.status, common_pb2.ORDER_STATUS_UNKNOWN),
            side=common_pb2.ORDER_SIDE_BUY if broker_order.is_buy else common_pb2.ORDER_SIDE_SELL,
            quantity=broker_order.quantity,
            filled_quantity=broker_order.filled_qty,
            avg_fill_price=broker_order.avg_price,
            created_at_us=broker_order.created_time * 1_000_000,
            updated_at_us=broker_order.updated_time * 1_000_000
        )
    
    def map_market_data(self, broker_quote):
        """Convert broker quote to protocol tick."""
        return market_data_pb2.TickData(
            symbol=broker_quote.symbol,
            bid=broker_quote.bid_price,
            ask=broker_quote.ask_price,
            bid_size=broker_quote.bid_size,
            ask_size=broker_quote.ask_size,
            last=broker_quote.last_price,
            last_size=broker_quote.last_size,
            exchange=broker_quote.exchange
        )
```

### Step 3: Handle Order Flow

```python
class OrderHandler:
    """Handles order flow from strategy to broker."""
    
    def __init__(self, broker_client, strategy_stub):
        self.broker = broker_client
        self.strategy = strategy_stub
    
    def handle_order_request(self, request):
        """Process order request from strategy."""
        # Validate with broker
        broker_validation = self.broker.validate_order(
            symbol=request.symbol,
            quantity=request.quantity,
            order_type=self._map_order_type(request.order_type)
        )
        
        if not broker_validation.valid:
            return orders_pb2.PlaceOrderResponse(
                accepted=False,
                reject_reason=broker_validation.reason,
                request_id=request.request_id
            )
        
        # Submit to broker
        broker_order = self.broker.submit_order(
            symbol=request.symbol,
            quantity=request.quantity,
            order_type=self._map_order_type(request.order_type),
            limit_price=request.limit_price if request.limit_price > 0 else None,
            client_order_id=request.client_order_id
        )
        
        # Return response
        return orders_pb2.PlaceOrderResponse(
            accepted=True,
            order_id=broker_order.id,
            request_id=request.request_id,
            estimated_fill_price=broker_order.estimated_price,
            timestamp_us=int(time.time() * 1_000_000)
        )
```

## Best Practices

### 1. Error Handling

Always implement proper error handling and recovery:

```python
def process_with_retry(self, event, max_retries=3):
    """Process event with retry logic."""
    for attempt in range(max_retries):
        try:
            response = self.stub.ProcessEvent(event, timeout=5.0)
            if response.success:
                return response
            
            # Log failure
            self.logger.warning(f"Event processing failed: {response.error}")
            
        except grpc.RpcError as e:
            if e.code() == grpc.StatusCode.UNAVAILABLE:
                # Retry on temporary failures
                time.sleep(2 ** attempt)
                continue
            else:
                # Don't retry on permanent failures
                raise
    
    raise Exception("Max retries exceeded")
```

### 2. Connection Management

Implement connection monitoring and reconnection:

```python
class ConnectionManager:
    def __init__(self, address):
        self.address = address
        self.channel = None
        self.stub = None
        self._connect()
    
    def _connect(self):
        """Establish connection with health checking."""
        self.channel = grpc.insecure_channel(
            self.address,
            options=[
                ('grpc.keepalive_time_ms', 10000),
                ('grpc.keepalive_timeout_ms', 5000),
                ('grpc.keepalive_permit_without_calls', True),
                ('grpc.http2.max_pings_without_data', 0),
            ]
        )
        self.stub = orders_pb2_grpc.TradingServiceStub(self.channel)
    
    def ensure_connected(self):
        """Ensure connection is alive."""
        try:
            # Try a lightweight operation
            grpc.channel_ready_future(self.channel).result(timeout=1)
        except grpc.FutureTimeoutError:
            self._connect()
```

### 3. Performance Optimization

For high-frequency strategies:

```python
# Use streaming for batch events
def stream_events(self, events):
    """Stream multiple events efficiently."""
    def event_generator():
        for event in events:
            yield event
    
    responses = self.stub.ProcessEventStream(event_generator())
    for response in responses:
        if not response.success:
            self.logger.error(f"Event failed: {response.error}")

# Use connection pooling
class ConnectionPool:
    def __init__(self, address, pool_size=5):
        self.channels = [
            grpc.insecure_channel(address)
            for _ in range(pool_size)
        ]
        self.current = 0
    
    def get_stub(self):
        channel = self.channels[self.current]
        self.current = (self.current + 1) % len(self.channels)
        return orders_pb2_grpc.TradingServiceStub(channel)
```

## Common Patterns

### 1. State Synchronization

Periodically sync state between strategy and provider:

```python
def sync_state(self):
    """Synchronize positions and orders."""
    # Get strategy's view
    strategy_state = self.strategy_stub.GetState(
        orders_pb2.StateRequest(
            include_positions=True,
            include_orders=True,
            include_account=True
        )
    )
    
    # Get broker's view
    broker_positions = self.broker.get_positions()
    broker_orders = self.broker.get_orders()
    
    # Reconcile differences
    self._reconcile_positions(strategy_state.positions, broker_positions)
    self._reconcile_orders(strategy_state.orders, broker_orders)
```

### 2. Order Lifecycle Management

Track orders through their complete lifecycle:

```python
class OrderTracker:
    def __init__(self):
        self.orders = {}  # order_id -> OrderState
    
    def track_order(self, order_id, request):
        """Start tracking an order."""
        self.orders[order_id] = OrderState(
            order_id=order_id,
            request=request,
            status=common_pb2.ORDER_STATUS_PENDING,
            created_at=time.time()
        )
    
    def update_order(self, order_id, update):
        """Update order state."""
        if order_id in self.orders:
            order = self.orders[order_id]
            order.status = update.status
            order.filled_quantity = update.filled_quantity
            
            # Check if terminal state
            if update.status in [
                common_pb2.ORDER_STATUS_FILLED,
                common_pb2.ORDER_STATUS_CANCELED,
                common_pb2.ORDER_STATUS_REJECTED
            ]:
                order.completed_at = time.time()
```

### 3. Risk Management Integration

Implement pre-trade and post-trade risk checks:

```python
class RiskManager:
    def __init__(self, limits):
        self.position_limit = limits.get('position_limit', 100000)
        self.order_limit = limits.get('order_limit', 10000)
        self.daily_loss_limit = limits.get('daily_loss_limit', 5000)
    
    def check_order(self, order_request, current_state):
        """Perform pre-trade risk checks."""
        result = common_pb2.RiskCheckResult()
        
        # Position limit check
        current_position = current_state.positions.get(order_request.symbol, 0)
        new_position = current_position + order_request.quantity
        
        if abs(new_position) > self.position_limit:
            result.warnings["position_limit"] = f"Would exceed position limit of {self.position_limit}"
        
        # Order size check
        order_value = order_request.quantity * order_request.limit_price
        if order_value > self.order_limit:
            result.warnings["order_limit"] = f"Order value {order_value} exceeds limit"
        
        # Daily loss check
        if current_state.daily_pnl < -self.daily_loss_limit:
            result.warnings["daily_loss"] = "Daily loss limit reached"
        
        return result
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Method not implemented" Error

**Problem**: Strategy doesn't implement all required methods.

**Solution**: Ensure all service methods are implemented, even if empty:

```python
def ValidateOrder(self, request, context):
    # Minimal implementation if not using validation
    return orders_pb2.ValidateOrderResponse(
        valid=True,
        request_id=request.request_id
    )
```

#### 2. Timeout Errors

**Problem**: RPC calls timing out.

**Solution**: Adjust timeout and implement retry logic:

```python
# Set appropriate timeouts
response = stub.ProcessEvent(event, timeout=30.0)

# For long operations, use streaming
stream = stub.ProcessEventStream(events)
for response in stream:
    process_response(response)
```

#### 3. Message Size Limits

**Problem**: "Received message larger than max" error.

**Solution**: Increase message size limits:

```python
# Client side
channel = grpc.insecure_channel(
    address,
    options=[
        ('grpc.max_receive_message_length', 100 * 1024 * 1024),  # 100MB
        ('grpc.max_send_message_length', 100 * 1024 * 1024),
    ]
)

# Server side
server = grpc.server(
    futures.ThreadPoolExecutor(),
    options=[
        ('grpc.max_receive_message_length', 100 * 1024 * 1024),
        ('grpc.max_send_message_length', 100 * 1024 * 1024),
    ]
)
```

#### 4. Version Mismatch

**Problem**: "Unknown field" or serialization errors.

**Solution**: Ensure both sides use compatible proto versions:

```bash
# Check proto version
buf breaking --against '.git#tag=v1.0.0'

# Regenerate code
buf generate

# Verify imports match
grep "^import" generated_pb2.py
```

### Debug Tips

1. **Enable gRPC Logging**:
```python
import grpc
import logging

logging.basicConfig(level=logging.DEBUG)
grpc_logger = logging.getLogger('grpc')
grpc_logger.setLevel(logging.DEBUG)
```

2. **Use gRPC Reflection**:
```python
from grpc_reflection.v1alpha import reflection

# Add to server
reflection.enable_server_reflection(SERVICE_NAMES, server)

# Test with grpcurl
# grpcurl -plaintext localhost:50051 list
```

3. **Monitor Metrics**:
```python
from prometheus_client import Counter, Histogram

order_counter = Counter('orders_placed_total', 'Total orders placed')
order_latency = Histogram('order_latency_seconds', 'Order placement latency')

@order_latency.time()
def place_order_with_metrics(self, request):
    response = self.place_order(request)
    if response.accepted:
        order_counter.inc()
    return response
```

---

For more examples and language-specific guides, see the [examples](../examples/) directory.