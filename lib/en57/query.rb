# frozen_string_literal: true

module En57
  QueryItem =
    Data.define(:types, :tags) do
      def self.all = new(types: [], tags: {})

      def with_tags(tags)
        with(tags: self.tags.merge(tags))
      end
    end

  Query =
    Data.define(:items) do
      def self.all = new(items: [])

      def refine_last
        existing_items = items.empty? ? [QueryItem.all] : items

        with(
          items: [*existing_items[0...-1], yield(existing_items.last)],
        )
      end
    end
end
