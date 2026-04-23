# frozen_string_literal: true

require "test_helper"

module En57
  class TestQuery < Minitest::Test
    cover Query
    cover QueryItem

    def test_query_item_with_tags_merges
      item = QueryItem.new(types: [], tags: { tenant_id: "acme" })

      assert_equal(
        QueryItem.new(types: [], tags: { tenant_id: "acme", order_id: "123" }),
        item.with_tags(order_id: "123"),
      )
    end

    def test_query_item_with_types_merges
      item = QueryItem.new(types: ["OrderPlaced"], tags: {})

      assert_equal(
        QueryItem.new(types: ["OrderPlaced", "PriceChanged"], tags: {}),
        item.with_types(["PriceChanged", "OrderPlaced"]),
      )
    end

    def test_refine_last_starts_from_all_item
      assert_equal(
        Query.new(items: [QueryItem.new(types: [], tags: { order_id: "123" })]),
        Query.all.refine_last { |item| item.with_tags(order_id: "123") },
      )
    end

    def test_refine_last_only_changes_last_item
      query =
        Query.new(
          items: [
            QueryItem.new(types: ["A"], tags: { tenant_id: "acme" }),
            QueryItem.new(types: ["B"], tags: { order_id: "123" }),
          ],
        )

      assert_equal(
        Query.new(
          items: [
            QueryItem.new(types: ["A"], tags: { tenant_id: "acme" }),
            QueryItem.new(
              types: ["B"],
              tags: { order_id: "123", user_id: "42" },
            ),
          ],
        ),
        query.refine_last { |item| item.with_tags(user_id: "42") },
      )
    end
  end
end
