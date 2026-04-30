# frozen_string_literal: true

require "test_helper"

module En57
  class TestQuery < TLDR
    cover Query

    def test_refine_last_starts_from_all_item
      assert_equal(
        Query.new(
          criteria: [Query::Criteria.new(types: [], tags: ["order_id:123"])],
        ),
        Query.all.refine_last { |item| item.with_tags(["order_id:123"]) },
      )
    end

    def test_refine_last_only_changes_last_item
      query =
        Query.new(
          criteria: [
            Query::Criteria.new(types: ["A"], tags: ["tenant_id:acme"]),
            Query::Criteria.new(types: ["B"], tags: ["order_id:123"]),
          ],
        )

      assert_equal(
        Query.new(
          criteria: [
            Query::Criteria.new(types: ["A"], tags: ["tenant_id:acme"]),
            Query::Criteria.new(
              types: ["B"],
              tags: %w[order_id:123 user_id:42],
            ),
          ],
        ),
        query.refine_last { |item| item.with_tags(["user_id:42"]) },
      )
    end

    def test_or_combines_criteria
      left =
        Query.new(criteria: [Query::Criteria.new(types: ["A"], tags: ["a:1"])])
      right =
        Query.new(criteria: [Query::Criteria.new(types: ["B"], tags: ["b:2"])])

      assert_equal(
        Query.new(
          criteria: [
            Query::Criteria.new(types: ["A"], tags: ["a:1"]),
            Query::Criteria.new(types: ["B"], tags: ["b:2"]),
          ],
        ),
        left.or(right),
      )
    end

    def test_or_with_all_returns_all
      left =
        Query.new(criteria: [Query::Criteria.new(types: ["A"], tags: ["a:1"])])

      assert_equal(Query.all, left.or(Query.all))
      assert_equal(Query.all, Query.all.or(left))
    end

    def test_encoded_criteria_omits_empty_fields
      query =
        Query.new(
          criteria: [
            Query::Criteria.new(types: ["OrderPlaced"], tags: []),
            Query::Criteria.new(types: [], tags: ["order_id:123"]),
            Query::Criteria.new(types: [], tags: [], after: 42),
            Query::Criteria.new(types: [], tags: []),
          ],
        )

      assert_equal(
        [
          { types: ["OrderPlaced"] },
          { tags: ["order_id:123"] },
          { after: 42 },
          {},
        ],
        query.encoded_criteria,
      )
    end
  end
end
