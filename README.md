# En57

DCB-compatible event store library in Ruby with support for PostgreSQL.

## Usage

### Connect with raw pg

Use `PgAdapter` when En57 should own its PostgreSQL connection.

```ruby
store =
  En57::EventStore.new(
    En57::Repository.new(
      En57::PgAdapter.new(
        "postgres://localhost:5432/en57",
        max_connections: 8,
      ),
      En57::JsonSerializer.new,
    ),
  )
```

### Connect with Sequel

Use `SequelAdapter` when your app already owns a Sequel database.

```ruby
database = Sequel.connect("postgres://localhost:5432/en57")

store =
  En57::EventStore.new(
    En57::Repository.new(
      En57::SequelAdapter.new(database),
      En57::JsonSerializer.new,
    ),
  )
```

### Connect with ActiveRecord

Use `ActiveRecordAdapter` when your app already owns an ActiveRecord pool.

```ruby
ActiveRecord::Base.establish_connection("postgres://localhost:5432/en57")

store =
  En57::EventStore.new(
    En57::Repository.new(
      En57::ActiveRecordAdapter.new(ActiveRecord::Base.connection_pool),
      En57::JsonSerializer.new,
    ),
  )
```

### Append events unconditionally

```ruby
store.append(
  [
    En57::Event.new(
      type: "OrderPlaced",
      data: { amount: 100 },
      tags: ["order_id:123", "customer:42"],
    ),
  ],
)
```

### Read all events

```ruby
events = store.read.each.to_a
```

### Read events with positions

```ruby
event, position = store.read.each_with_position.first
```

### Read events filtered by tags

```ruby
events = store.read.with_tag("order_id:123", "customer:42").each.to_a
```

### Read events after a position

```ruby
events = store.read.after(42).each.to_a
```

### Read events filtered by merged scopes

```ruby
orders = store.read.of_type("OrderPlaced").with_tag("order_id:123")
price_changes = store.read.of_type("PriceChanged")

events = (orders | price_changes).each.to_a
```

### Conditional write (optimistic concurrency style)

Example: consume credits only once per account.

```ruby
account_scope = store.read.with_tag("account:x")

begin
  store.append(
    [
      En57::Event.new(
        type: "CreditsUsed",
        data: { amount: 100 },
        tags: ["account:x"],
      ),
    ],
    fail_if: account_scope.of_type("CreditsUsed"),
  )
rescue En57::AppendConditionViolated
  # lost the race; another writer already consumed credits
end
```

To ignore events at or before a known position, scope the `fail_if` condition
with `after`.

```ruby
last_read_event_position = 42

store.append(
  [En57::Event.new(type: "CreditsUsed", tags: ["account:x"])],
  fail_if: store.read.of_type("CreditsUsed").after(last_read_event_position),
)
```

### Conditional write for email uniqueness

Example: ensure no event exists with this email tag before writing.

```ruby
email_tag = "email:alice@example.com"

begin
  store.append(
    [
      En57::Event.new(
        type: "UserRegistered",
        data: { name: "Alice" },
        tags: [email_tag],
      ),
    ],
    fail_if: store.read.with_tag(email_tag),
  )
rescue En57::AppendConditionViolated
  # email already used
end
```
