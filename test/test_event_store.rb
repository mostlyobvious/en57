# frozen_string_literal: true

require "test_helper"

module En57
  class TestEventStore < Minitest::Test
    cover EventStore

    def credit_topped_up
      @credit_topped_up ||=
        Event.new(id: SecureRandom.uuid, type: "CredditToppedUp")
    end

    def test_append_event
      repository = Minitest::Mock.new
      repository.expect(:append, nil, [[credit_topped_up]])

      EventStore.new(repository).append([credit_topped_up])

      repository.verify
    end

    def test_read_returns_scope_for_query_all
      repository = Minitest::Mock.new
      repository.expect(:read, [credit_topped_up], [Query.all])

      result = EventStore.new(repository).read

      assert_instance_of(Scope, result)
      assert_equal([credit_topped_up], result.each.to_a)

      repository.verify
    end

    def test_return_self_from_append
      repository = Minitest::Mock.new
      repository.expect(:append, nil, [[credit_topped_up]])

      event_store = EventStore.new(repository)

      assert_equal(event_store, event_store.append([credit_topped_up]))

      repository.verify
    end
  end
end
