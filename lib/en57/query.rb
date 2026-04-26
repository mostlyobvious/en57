# frozen_string_literal: true

module En57
  class Query < Data.define(:criteria)
    Criteria =
      Data.define(:types, :tags, :after) do
        def initialize(types:, tags:, after: nil) = super

        def self.all = new(types: [], tags: [])

        def with_tags(tags)
          with(tags: [*self.tags, *tags])
        end

        def with_types(types)
          with(types: [*self.types, *types].uniq)
        end

        def with_after(position)
          with(after: position)
        end

        def matcher
          { types:, tags:, after: }.reject do |key, value|
            key == :after ? value.nil? : value.empty?
          end
        end
      end

    def encoded_criteria = criteria.map(&:matcher)

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
