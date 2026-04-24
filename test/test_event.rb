# frozen_string_literal: true

require "test_helper"

module En57
  class TestEvent < Minitest::Test
    cover Event

    def test_generates_uuid_v7_by_default
      event = Event.new(type: "OrderPlaced")

      assert_match(
        /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/,
        event.id,
      )
    end

    def test_defaults_data_and_tags
      event = Event.new(type: "OrderPlaced")

      assert_equal({}, event.data)
      assert_equal([], event.tags)
    end
  end
end
