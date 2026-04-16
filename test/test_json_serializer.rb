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

    EXAMPLES = [
      %w[string str str String],
      ["symbol", :sym, "sym", "Symbol"],
      ["date", Date.new(2024, 1, 1), "2024-01-01", "Date"],
      ["time", Time.utc(2024, 1, 1, 12, 0, 0), "2024-01-01T12:00:00Z", "Time"],
      ["big_decimal", BigDecimal("1.5"), "1.5", "BigDecimal"],
      ["integer", 100, 100, "Integer"],
      ["float", 1.5, 1.5, "Float"],
      ["true", true, true, "TrueClass"],
      ["false", false, false, "FalseClass"],
      ["nil", nil, nil, "NilClass"],
    ].freeze

    NATIVE_VALUES = %w[
      String
      Integer
      Float
      TrueClass
      FalseClass
      NilClass
    ].freeze

    EXAMPLES.each do |key_name, key_obj, key_dumped, key_klass|
      EXAMPLES.each do |value_name, value_obj, value_dumped, value_klass|
        payload = { key_obj => value_obj }
        serialized = JSON.generate({ key_dumped => value_dumped })
        description = {}
        description["keys"] = { key_dumped => key_klass } unless key_klass ==
          "String"
        description["values"] = {
          key_dumped => value_klass,
        } unless NATIVE_VALUES.include?(value_klass)
        description_json = JSON.generate(description)

        define_method("test_dump_#{key_name}_key_#{value_name}_value") do
          assert_equal [serialized, description_json], serializer.dump(payload)
        end

        define_method("test_load_#{key_name}_key_#{value_name}_value") do
          assert_equal payload, serializer.load(serialized, description_json)
        end
      end
    end
  end
end
