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
      @key_types.register(Type.new(Integer, IDENTITY, lambda { Integer(it) }))
    end

    def dump(payload)
      key_meta = {}
      value_meta = {}
      serialized =
        payload.to_h do |k, v|
          ktype = @key_types.for_class(k.class)
          if ktype
            dumped_key = ktype.dump.call(k)
            key_meta[dumped_key] = ktype.klass
          else
            dumped_key = k
          end
          vtype = @value_types.for_class(v.class)
          if vtype
            value_meta[dumped_key] = vtype.klass
            [dumped_key, vtype.dump.call(v)]
          else
            [dumped_key, v]
          end
        end
      metadata = {}
      metadata["keys"] = key_meta unless key_meta.empty?
      metadata["values"] = value_meta unless value_meta.empty?
      [JSON.generate(serialized), JSON.generate(metadata)]
    end

    def load(string, description)
      desc = JSON.parse(description)
      keys = desc["keys"] || {}
      values = desc["values"] || {}
      JSON
        .parse(string)
        .to_h do |k, v|
          kname = keys[k]
          new_key = kname ? @key_types.by_name(kname).load.call(k) : k
          vname = values[k]
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
