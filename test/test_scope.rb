# frozen_string_literal: true

require "test_helper"

module En57
  class TestScope < TLDR
    cover Scope

    def test_empty_scope_returns_query_all
      assert_equal(Query.all, EmptyScope.new.to_query)
    end

    def test_each_without_block_returns_enumerator
      with_repository do |repository|
        assert_instance_of(Enumerator, Scope.new(repository, Query.all).each)
      end
    end

    def test_each_with_position_without_block_returns_enumerator
      with_repository do |repository|
        repository.expect(:read, [[:event_1, 1], [:event_2, 2]], [Query.all])

        assert_equal(
          [[:event_1, 1], [:event_2, 2]],
          Scope.new(repository, Query.all).each_with_position.to_a,
        )
      end
    end

    def test_each_with_block_yields_events
      with_repository do |repository|
        scope = Scope.new(repository, Query.all)
        yielded = []
        repository.expect(:read, [[:event_1, 1], [:event_2, 2]], [Query.all])

        scope.each { |event| yielded << event }

        assert_equal(%i[event_1 event_2], yielded)
      end
    end

    def test_each_with_position_yields_events_and_positions
      with_repository do |repository|
        yielded = []
        repository.expect(:read, [[:event_1, 1], [:event_2, 2]], [Query.all])

        Scope
          .new(repository, Query.all)
          .each_with_position { |event, position| yielded << [event, position] }

        assert_equal([[:event_1, 1], [:event_2, 2]], yielded)
      end
    end

    def test_with_tag_refines_query
      with_repository do |repository|
        repository.expect(:read, [], [Query.all])
        repository.expect(
          :read,
          [],
          [
            Query.new(
              criteria: [
                Query::Criteria.new(types: [], tags: ["order_id:123"]),
              ],
            ),
          ],
        )

        assert_equal([], Scope.new(repository, Query.all).each.to_a)
        assert_equal(
          [],
          Scope.new(repository, Query.all).with_tag("order_id:123").each.to_a,
        )
      end
    end

    def test_of_type_refines_query
      with_repository do |repository|
        repository.expect(:read, [], [Query.all])
        repository.expect(
          :read,
          [],
          [
            Query.new(
              criteria: [
                Query::Criteria.new(
                  types: %w[OrderPlaced OrderCancelled],
                  tags: [],
                ),
              ],
            ),
          ],
        )

        assert_equal([], Scope.new(repository, Query.all).each.to_a)
        assert_equal(
          [],
          Scope
            .new(repository, Query.all)
            .of_type("OrderPlaced", "OrderCancelled")
            .each
            .to_a,
        )
      end
    end

    def test_scope_or_returns_merged_scope
      with_repository do |repository|
        combined =
          Scope
            .new(repository, Query.all)
            .of_type("OrderPlaced")
            .or(Scope.new(repository, Query.all).with_tag("order_id:123"))

        assert_instance_of(MergedScope, combined)

        repository.expect(
          :read,
          [],
          [
            Query.new(
              criteria: [
                Query::Criteria.new(types: ["OrderPlaced"], tags: []),
                Query::Criteria.new(types: [], tags: ["order_id:123"]),
              ],
            ),
          ],
        )

        assert_equal([], combined.each.to_a)
      end
    end

    def test_merged_scope_each_without_block_returns_enumerator
      with_repository do |repository|
        assert_instance_of(Enumerator, merged_scope(repository).each)
      end
    end

    def test_merged_scope_each_with_position_without_block_returns_enumerator
      with_repository do |repository|
        repository.expect(
          :read,
          [[:event_1, 1], [:event_2, 2]],
          [
            Query.new(
              criteria: [
                Query::Criteria.new(types: ["OrderPlaced"], tags: []),
                Query::Criteria.new(types: [], tags: ["order_id:123"]),
              ],
            ),
          ],
        )

        assert_equal(
          [[:event_1, 1], [:event_2, 2]],
          merged_scope(repository).each_with_position.to_a,
        )
      end
    end

    def test_merged_scope_each_with_block_yields_events
      with_repository do |repository|
        merged =
          Scope
            .new(repository, Query.all)
            .of_type("OrderPlaced")
            .or(Scope.new(repository, Query.all).with_tag("order_id:123"))
        yielded = []

        repository.expect(
          :read,
          [[:event_1, 1], [:event_2, 2]],
          [
            Query.new(
              criteria: [
                Query::Criteria.new(types: ["OrderPlaced"], tags: []),
                Query::Criteria.new(types: [], tags: ["order_id:123"]),
              ],
            ),
          ],
        )

        merged.each { |event| yielded << event }

        assert_equal(%i[event_1 event_2], yielded)
      end
    end

    def test_merged_scope_each_with_position_yields_events_and_positions
      with_repository do |repository|
        yielded = []

        repository.expect(
          :read,
          [[:event_1, 1], [:event_2, 2]],
          [
            Query.new(
              criteria: [
                Query::Criteria.new(types: ["OrderPlaced"], tags: []),
                Query::Criteria.new(types: [], tags: ["order_id:123"]),
              ],
            ),
          ],
        )

        merged_scope(repository).each_with_position do |event, position|
          yielded << [event, position]
        end

        assert_equal([[:event_1, 1], [:event_2, 2]], yielded)
      end
    end

    def test_merged_scope_or_returns_merged_scope
      with_repository do |repository|
        scope = Scope.new(repository, Query.all)
        extended =
          scope
            .of_type("OrderPlaced")
            .or(scope.with_tag("order_id:123"))
            .or(scope.with_tag("customer_id:456"))

        assert_instance_of(MergedScope, extended)

        repository.expect(
          :read,
          [],
          [
            Query.new(
              criteria: [
                Query::Criteria.new(types: ["OrderPlaced"], tags: []),
                Query::Criteria.new(types: [], tags: ["order_id:123"]),
                Query::Criteria.new(types: [], tags: ["customer_id:456"]),
              ],
            ),
          ],
        )

        assert_equal([], extended.each.to_a)
      end
    end

    def test_after_refines_query
      with_repository do |repository|
        repository.expect(
          :read,
          [],
          [
            Query.new(
              criteria: [Query::Criteria.new(types: [], tags: [], after: 42)],
            ),
          ],
        )

        assert_equal([], Scope.new(repository, Query.all).after(42).each.to_a)
      end
    end

    def test_merged_scope_cannot_be_refined_anymore
      with_repository do |repository|
        merged =
          Scope
            .new(repository, Query.all)
            .of_type("OrderPlaced")
            .or(Scope.new(repository, Query.all).with_tag("order_id:123"))

        assert_raises(NoMethodError) { merged.with_tag("customer_id:456") }
        assert_raises(NoMethodError) { merged.of_type("OrderCancelled") }
        assert_raises(NoMethodError) { merged.after(42) }
      end
    end

    def test_pipe_aliases_or
      with_repository do |repository|
        assert_instance_of(
          MergedScope,
          Scope.new(repository, Query.all).of_type("OrderPlaced") |
            Scope.new(repository, Query.all).with_tag("order_id:123"),
        )
      end
    end

    def test_scope_exposes_to_query
      with_repository do |repository|
        scope = Scope.new(repository, Query.all).with_tag("order_id:123")

        assert_equal(
          Query.new(
            criteria: [Query::Criteria.new(types: [], tags: ["order_id:123"])],
          ),
          scope.to_query,
        )
      end
    end

    def test_merged_scope_exposes_to_query
      with_repository do |repository|
        merged =
          Scope
            .new(repository, Query.all)
            .of_type("OrderPlaced")
            .or(Scope.new(repository, Query.all).with_tag("order_id:123"))

        assert_equal(
          Query.new(
            criteria: [
              Query::Criteria.new(types: ["OrderPlaced"], tags: []),
              Query::Criteria.new(types: [], tags: ["order_id:123"]),
            ],
          ),
          merged.to_query,
        )
      end
    end

    private

    def merged_scope(repository)
      Scope
        .new(repository, Query.all)
        .of_type("OrderPlaced")
        .or(Scope.new(repository, Query.all).with_tag("order_id:123"))
    end

    def with_repository
      repository = Minitest::Mock.new
      yield repository
      repository.verify
    end
  end
end
