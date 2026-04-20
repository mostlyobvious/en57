# frozen_string_literal: true

require "test_helper"
require "date"
require "time"
require "bigdecimal"
require "json"

module En57
  class TestJsonSerializer < Minitest::Test
    cover JsonSerializer

    def serializer = JsonSerializer.new

    example =
      Data.define(:name, :value, :serialized) do
        def json_native?
          [String, Integer, Float, TrueClass, FalseClass, NilClass].any? do
            it === value
          end
        end

        def klass = value.class.name
      end

    [
      %w[string str str],
      ["symbol", :sym, "sym"],
      ["date", Date.new(2024, 1, 1), "2024-01-01"],
      ["time", Time.utc(2024, 1, 1, 12, 0, 0), "2024-01-01T12:00:00Z"],
      ["big_decimal", BigDecimal("1.5"), "1.5"],
      ["integer", 100, 100],
      ["float", 1.5, 1.5],
      ["true", true, true],
      ["false", false, false],
      ["nil", nil, nil],
    ].map { example.new(*it) }
      .permutation(2) do |k, v|
        meta = {}
        meta["keys"] = { k.serialized => k.klass } unless String === k.value
        meta["values"] = { k.serialized => v.klass } unless v.json_native?

        payload = { k.value => v.value }
        serialized = JSON.dump({ k.serialized => v.serialized })

        define_method("test_dump_#{k.name}_key_#{v.name}_value") do
          assert_equal([serialized, JSON.dump(meta)], serializer.dump(payload))
        end

        define_method("test_load_#{k.name}_key_#{v.name}_value") do
          assert_equal(payload, serializer.load(serialized, JSON.dump(meta)))
        end
      end
  end
end
