# frozen_string_literal: true

require "json"
require "date"
require "time"

module En57
  class JsonSerializer
    IDENTITY = lambda { it }
    KeyType = Data.define(:klass, :load)
    ValueType = Data.define(:klass, :dump, :load)

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
      [
        KeyType.new(Symbol, lambda { it.to_sym }),
        KeyType.new(String, IDENTITY),
      ].each { @key_types.register(it) }

      @value_types = Registry.new
      [
        ValueType.new(Date, IDENTITY, lambda { Date.iso8601(it) }),
        ValueType.new(Time, lambda { it.iso8601 }, lambda { Time.iso8601(it) }),
        *optional_big_decimal_type,
      ].each { @value_types.register(it) }
    end

    def dump(payload)
      key_meta = {}
      value_meta = {}
      serialized =
        payload.to_h do |k, v|
          key_meta[k] = @key_types.for_class(k.class).klass
          vtype = @value_types.for_class(v.class)
          if vtype
            value_meta[k] = vtype.klass
            [k, vtype.dump.call(v)]
          else
            [k, v]
          end
        end
      metadata = { "keys" => key_meta }
      metadata["values"] = value_meta unless value_meta.empty?
      [JSON.generate(serialized), JSON.generate(metadata)]
    end

    def load(string, description)
      desc = JSON.parse(description)
      keys = desc.fetch("keys")
      values = desc["values"] || {}
      JSON
        .parse(string)
        .to_h do |k, v|
          new_key = @key_types.by_name(keys.fetch(k)).load.call(k)
          vname = values[k]
          new_val = vname ? @value_types.by_name(vname).load.call(v) : v
          [new_key, new_val]
        end
    end

    private

    def optional_big_decimal_type
      return [] unless defined?(BigDecimal)
      [
        ValueType.new(
          BigDecimal,
          lambda { it.to_s("F") },
          lambda { BigDecimal(it) },
        ),
      ]
    end
  end
end
