# frozen_string_literal: true

require "json"
require "date"
require "time"

module En57
  class JsonSerializer
    IDENTITY = lambda { it }
    Type = Data.define(:klass, :dump, :load)

    class Registry
      def initialize
        @by_class = {}
        @by_name = {}
      end

      def register(type)
        @by_class[type.klass] = type
        @by_name[type.klass.name] = type
      end

      def for_class(klass) = @by_class[klass]

      def by_name(name) = @by_name.fetch(name)
    end

    def initialize
      @key_types = Registry.new
      @value_types = Registry.new
      [
        Type.new(Symbol, IDENTITY, lambda { it.to_sym }),
        Type.new(Date, IDENTITY, lambda { Date.iso8601(it) }),
        Type.new(Time, lambda { it.iso8601 }, lambda { Time.iso8601(it) }),
        *optional_big_decimal_type,
      ].each do |type|
        @key_types.register(type)
        @value_types.register(type)
      end
      [
        Type.new(Integer, IDENTITY, lambda { Integer(it) }),
        Type.new(Float, IDENTITY, lambda { Float(it) }),
        Type.new(TrueClass, IDENTITY, lambda { |_| true }),
        Type.new(FalseClass, IDENTITY, lambda { |_| false }),
        Type.new(NilClass, IDENTITY, lambda { |_| }),
      ].each { @key_types.register(it) }
    end

    def dump(payload)
      metadata = Hash.new { |h, k| h[k] = {} }
      serialized =
        payload.to_h do |k, v|
          ktype = @key_types.for_class(k.class)
          dumped_key = ktype ? ktype.dump.call(k) : k
          metadata[dumped_key]["k"] = ktype.klass if ktype
          vtype = @value_types.for_class(v.class)
          dumped_value = vtype ? vtype.dump.call(v) : v
          metadata[dumped_key]["v"] = vtype.klass if vtype
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
      [Type.new(BigDecimal, lambda { it.to_s("F") }, lambda { BigDecimal(it) })]
    end
  end
end
