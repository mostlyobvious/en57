# frozen_string_literal: true

module En57
  class Query < Data.define(:criteria)
    Criteria =
      Data.define(:types, :tags) do
        def self.all = new(types: [], tags: [])

        def with_tags(tags)
          with(tags: [*self.tags, *tags])
        end

        def with_types(types)
          with(types: [*self.types, *types].uniq)
        end
      end

    def self.all = new(criteria: [])

    def refine_last
      case criteria
      in []
        with(criteria: [yield(Criteria.all)])
      in [*head, last]
        with(criteria: [*head, yield(last)])
      end
    end

    def or(other)
      return self.class.all if criteria.empty? || other.criteria.empty?

      with(criteria: [*criteria, *other.criteria])
    end
  end
end
