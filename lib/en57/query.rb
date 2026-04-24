# frozen_string_literal: true

module En57
  QueryItem =
    Data.define(:types, :tags) do
      def self.all = new(types: [], tags: {})

      def with_tags(tags)
        with(tags: self.tags.merge(tags))
      end

      def with_types(types)
        with(types: [*self.types, *types].uniq)
      end
    end

  Query =
    Data.define(:criteria) do
      def self.all = new(criteria: [])

      def refine_last
        existing = criteria.empty? ? [QueryItem.all] : criteria

        with(criteria: [*existing[0...-1], yield(existing.last)])
      end

      def or(other)
        return self.class.all if criteria.empty? || other.criteria.empty?

        with(criteria: [*criteria, *other.criteria])
      end
    end
end
