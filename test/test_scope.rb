# frozen_string_literal: true

require "test_helper"

module En57
  class TestScope < Minitest::Test
    cover Scope

    def test_each_without_block_returns_enumerator
      repository = Minitest::Mock.new
      scope = Scope.new(repository, Query.all)

      assert_instance_of(Enumerator, scope.each)
    end

    def test_each_with_block_yields_events
      repository = Minitest::Mock.new
      scope = Scope.new(repository, Query.all)
      yielded = []
      repository.expect(:read, [1, 2], [Query.all])

      scope.each { |event| yielded << event }

      assert_equal([1, 2], yielded)
      repository.verify
    end

    def test_with_tag_refines_query
      repository = Minitest::Mock.new
      base_scope = Scope.new(repository, Query.all)
      filtered_scope = base_scope.with_tag(order_id: "123")

      repository.expect(:read, [], [Query.all])
      repository.expect(
        :read,
        [],
        [
          Query.new(
            criteria: [
              Query::Criteria.new(types: [], tags: { order_id: "123" }),
            ],
          ),
        ],
      )

      assert_equal([], base_scope.each.to_a)
      assert_equal([], filtered_scope.each.to_a)
      repository.verify
    end

    def test_of_type_refines_query
      repository = Minitest::Mock.new
      base_scope = Scope.new(repository, Query.all)
      filtered_scope = base_scope.of_type("OrderPlaced", "OrderCancelled")

      repository.expect(:read, [], [Query.all])
      repository.expect(
        :read,
        [],
        [
          Query.new(
            criteria: [
              Query::Criteria.new(
                types: %w[OrderPlaced OrderCancelled],
                tags: {
                },
              ),
            ],
          ),
        ],
      )

      assert_equal([], base_scope.each.to_a)
      assert_equal([], filtered_scope.each.to_a)
      repository.verify
    end

    def test_scope_or_returns_merged_scope
      repository = Minitest::Mock.new
      left = Scope.new(repository, Query.all).of_type("OrderPlaced")
      right = Scope.new(repository, Query.all).with_tag(order_id: "123")
      combined = left.or(right)

      assert_instance_of(MergedScope, combined)

      repository.expect(
        :read,
        [],
        [
          Query.new(
            criteria: [
              Query::Criteria.new(types: ["OrderPlaced"], tags: {}),
              Query::Criteria.new(types: [], tags: { order_id: "123" }),
            ],
          ),
        ],
      )

      assert_equal([], combined.each.to_a)
      repository.verify
    end

    def test_merged_scope_or_returns_merged_scope
      repository = Minitest::Mock.new
      base = Scope.new(repository, Query.all)
      merged = base.of_type("OrderPlaced").or(base.with_tag(order_id: "123"))
      extended = merged.or(base.with_tag(customer_id: "456"))

      assert_instance_of(MergedScope, extended)

      repository.expect(
        :read,
        [],
        [
          Query.new(
            criteria: [
              Query::Criteria.new(types: ["OrderPlaced"], tags: {}),
              Query::Criteria.new(types: [], tags: { order_id: "123" }),
              Query::Criteria.new(types: [], tags: { customer_id: "456" }),
            ],
          ),
        ],
      )

      assert_equal([], extended.each.to_a)
      repository.verify
    end

    def test_merged_scope_cannot_be_refined_anymore
      repository = Minitest::Mock.new
      base = Scope.new(repository, Query.all)
      merged = base.of_type("OrderPlaced").or(base.with_tag(order_id: "123"))

      assert_raises(NoMethodError) { merged.with_tag(customer_id: "456") }
      assert_raises(NoMethodError) { merged.of_type("OrderCancelled") }
    end

    def test_pipe_aliases_or
      repository = Minitest::Mock.new
      left = Scope.new(repository, Query.all).of_type("OrderPlaced")
      right = Scope.new(repository, Query.all).with_tag(order_id: "123")

      assert_instance_of(MergedScope, left | right)
    end
  end
end
