# frozen_string_literal: true

require "test_helper"

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
