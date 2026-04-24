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
      repository =
        Class
          .new do
            attr_reader :args, :kwargs

            def append(*args, **kwargs)
              @args = args
              @kwargs = kwargs
            end
          end
          .new

      EventStore.new(repository).append([credit_topped_up])

      assert_equal([[credit_topped_up]], repository.args)
      assert_equal({ fail_if: Query.all, after: nil }, repository.kwargs)
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
      repository = Class.new { def append(*, **) = nil }.new

      event_store = EventStore.new(repository)

      assert_equal(event_store, event_store.append([credit_topped_up]))
    end

    def test_append_forwards_options
      repository =
        Class
          .new do
            attr_reader :kwargs

            def append(*, **kwargs)
              @kwargs = kwargs
            end
          end
          .new

      EventStore.new(repository).append([credit_topped_up], after: 42)

      assert_equal({ fail_if: Query.all, after: 42 }, repository.kwargs)
    end
  end
end
