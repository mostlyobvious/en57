# frozen_string_literal: true

require "test_helper"

module En57
  class TestJsonSerializer < Minitest::Test
    cover JsonSerializer

    def test_dump
      assert_equal('{"amount":100}', JsonSerializer.new.dump({amount: 100}))
    end

    def test_load
      assert_equal({"amount" => 100}, JsonSerializer.new.load('{"amount":100}'))
    end
  end
end
