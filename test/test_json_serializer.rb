# frozen_string_literal: true

require "test_helper"
require "date"
require "time"
require "bigdecimal"

module En57
  class TestJsonSerializer < Minitest::Test
    cover JsonSerializer

    def serializer = JsonSerializer.new

    {
      "string_key" => [
        { "amount" => 100 },
        %({"amount":100}),
        %({"keys":{"amount":"String"}}),
      ],
      "symbol_key" => [
        { amount: 100 },
        %({"amount":100}),
        %({"keys":{"amount":"Symbol"}}),
      ],
      "date_value" => [
        { "d" => Date.new(2024, 1, 1) },
        %({"d":"2024-01-01"}),
        %({"keys":{"d":"String"},"values":{"d":"Date"}}),
      ],
      "time_value" => [
        { "t" => Time.utc(2024, 1, 1, 12, 0, 0) },
        %({"t":"2024-01-01T12:00:00Z"}),
        %({"keys":{"t":"String"},"values":{"t":"Time"}}),
      ],
      "big_decimal_value" => [
        { "b" => BigDecimal("1.5") },
        %({"b":"1.5"}),
        %({"keys":{"b":"String"},"values":{"b":"BigDecimal"}}),
      ],
    }.each do |name, (original, serialized, description)|
      define_method("test_dump_#{name}") do
        assert_equal [serialized, description], serializer.dump(original)
      end

      define_method("test_load_#{name}") do
        assert_equal original, serializer.load(serialized, description)
      end
    end
  end
end
