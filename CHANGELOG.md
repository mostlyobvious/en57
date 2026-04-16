## [Unreleased]

- `JsonSerializer` now serializes `Date`, `Time`, and `BigDecimal`
  values in event payloads alongside `String`/`Symbol` keys. Typed
  values round-trip via ISO 8601 / string form; only payloads that
  contain typed values carry a `"values"` key in the description.
