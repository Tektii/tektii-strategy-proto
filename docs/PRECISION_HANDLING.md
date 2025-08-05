# Precision Handling Guide

## Overview

The Tektii Strategy Protocol uses `PreciseDecimal` for all monetary values, prices, quantities, and percentages to ensure precision-safe decimal representation. This is critical for:
- **Crypto trading**: Supporting 8+ decimal places
- **Forex trading**: Accurate pip calculations  
- **Financial calculations**: Avoiding floating-point precision errors

## PreciseDecimal Structure

```proto
message PreciseDecimal {
  int64 value = 1;  // Scaled integer value
  int32 scale = 2;  // Number of decimal places
}
```

### Examples
- `1.23456` is represented as `{value: 123456, scale: 5}`
- `$100.00` is represented as `{value: 10000, scale: 2}`
- `0.00000001 BTC` is represented as `{value: 1, scale: 8}`

## Validation Rules

### 1. Scale Limits

Different asset classes have different precision requirements:

| Asset Type  | Recommended Scale | Maximum Scale |
| ----------- | ----------------- | ------------- |
| Forex       | 5                 | 6             |
| Crypto      | 8                 | 12            |
| Equities    | 2                 | 4             |
| Commodities | 4                 | 6             |

### 2. Value Range

- `value` must fit within int64 range: `-9,223,372,036,854,775,808` to `9,223,372,036,854,775,807`
- Consider the actual value after scaling: `actual_value = value * 10^(-scale)`

### 3. Normalization

Values should be normalized to remove trailing zeros:
- `{value: 12300, scale: 2}` should be `{value: 123, scale: 0}` for integer values
- `{value: 123400, scale: 4}` should be `{value: 1234, scale: 2}`

## Implementation Guidelines

### Converting from Double

```python
def double_to_precise_decimal(value: float, scale: int) -> PreciseDecimal:
    """Convert a floating-point value to PreciseDecimal."""
    scaled_value = int(round(value * (10 ** scale)))
    return PreciseDecimal(value=scaled_value, scale=scale)
```

### Converting to Double

```python
def precise_decimal_to_double(pd: PreciseDecimal) -> float:
    """Convert PreciseDecimal to floating-point value."""
    return pd.value / (10 ** pd.scale)
```

### Arithmetic Operations

```python
def add_precise_decimals(a: PreciseDecimal, b: PreciseDecimal) -> PreciseDecimal:
    """Add two PreciseDecimal values."""
    if a.scale == b.scale:
        return PreciseDecimal(value=a.value + b.value, scale=a.scale)
    else:
        # Align to higher scale
        max_scale = max(a.scale, b.scale)
        a_aligned = a.value * (10 ** (max_scale - a.scale))
        b_aligned = b.value * (10 ** (max_scale - b.scale))
        return PreciseDecimal(value=a_aligned + b_aligned, scale=max_scale)
```

## Provider-Specific Considerations

### Interactive Brokers
- Forex: Use scale=5 for major pairs, scale=3 for JPY pairs
- Equities: Use scale=2 for USD stocks

### Binance
- Crypto: Use scale=8 for most pairs
- Check symbol info endpoint for specific precision requirements

### Alpaca
- Equities: Use scale=2 for all US stocks
- Crypto: Use scale=8 for all crypto pairs

## Validation Checklist

When implementing PreciseDecimal validation:

1. ✓ Verify scale is within acceptable range for asset type
2. ✓ Check value doesn't overflow int64 when scaled
3. ✓ Ensure positive values for quantities (except short positions)
4. ✓ Validate price values are positive (except for P&L)
5. ✓ Normalize values to remove unnecessary precision
6. ✓ Handle currency-specific precision (e.g., JPY typically has scale=0)

## Error Handling

Common validation errors:

- `INVALID_SCALE`: Scale exceeds maximum for asset type
- `VALUE_OVERFLOW`: Scaled value exceeds int64 range
- `NEGATIVE_QUANTITY`: Negative value where positive required
- `PRECISION_MISMATCH`: Operations on incompatible scales
