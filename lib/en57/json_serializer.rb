# frozen_string_literal: true

require "json"
require "date"
require "time"

module En57
  class JsonSerializer
    IDENTITY = lambda { it }
    BINARY = lambda { String === it && it.encoding == Encoding::BINARY }
    Type = Data.define(:match, :name, :dump, :load)

    class Registry
      def initialize
        @types = []
        @by_name = {}
      end

      def register(type)
        @types << type
        @by_name[type.name] = type
      end

      def for_value(value) = @types.find { it.match === value }

      def by_name(name) = @by_name.fetch(name)
    end

    def initialize
      @key_types = Registry.new
      @value_types = Registry.new
      [
        Type.new(Symbol, "Symbol", IDENTITY, lambda { it.to_sym }),
        Type.new(Date, "Date", IDENTITY, lambda { Date.iso8601(it) }),
        Type.new(
          Time,
          "Time",
          lambda { it.iso8601 },
          lambda { Time.iso8601(it) },
        ),
        Type.new(
          BINARY,
          "ASCII-8BIT",
          lambda { [it].pack("m0") },
          lambda { it.unpack1("m0") },
        ),
        *optional_big_decimal_type,
      ].each do |type|
        @key_types.register(type)
        @value_types.register(type)
      end
      [
        Type.new(Integer, "Integer", IDENTITY, lambda { Integer(it) }),
        Type.new(Float, "Float", IDENTITY, lambda { Float(it) }),
        Type.new(TrueClass, "TrueClass", IDENTITY, lambda { |_| true }),
        Type.new(FalseClass, "FalseClass", IDENTITY, lambda { |_| false }),
        Type.new(nil, "NilClass", IDENTITY, lambda { |_| }),
      ].each { @key_types.register(it) }
    end

    def dump(payload)
      metadata = Hash.new { |h, k| h[k] = {} }
      serialized =
        payload.to_h do |k, v|
          ktype = @key_types.for_value(k)
          dumped_key = ktype ? ktype.dump.call(k) : k
          metadata[dumped_key]["k"] = ktype.name if ktype
          vtype = @value_types.for_value(v)
          dumped_value = vtype ? vtype.dump.call(v) : v
          metadata[dumped_key]["v"] = vtype.name if vtype
          [dumped_key, dumped_value]
        end
      [JSON.generate(serialized), JSON.generate(metadata)]
    end

    def load(string, description)
      desc = JSON.parse(description)
      JSON
        .parse(string)
        .to_h do |k, v|
          entry = desc[k] || {}
          kname = entry["k"]
          vname = entry["v"]
          new_key = kname ? @key_types.by_name(kname).load.call(k) : k
          new_val = vname ? @value_types.by_name(vname).load.call(v) : v
          [new_key, new_val]
        end
    end

    private

    def optional_big_decimal_type
      return [] unless defined?(BigDecimal)
      [
        Type.new(
          BigDecimal,
          "BigDecimal",
          lambda { it.to_s("F") },
          lambda { BigDecimal(it) },
        ),
      ]
    end
  end
end
