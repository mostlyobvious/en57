# frozen_string_literal: true

module En57
  Scope =
    Data.define(:repository, :query) do
      def each(&block)
        return enum_for unless block

        repository.read(query).each(&block)
      end

      def with_tag(**tags)
        with(query: query.refine_last { |item| item.with_tags(tags) })
      end

      def of_type(*types)
        with(query: query.refine_last { |item| item.with_types(types) })
      end

      def or(other)
        with(query: query.or(other.query))
      end
      alias_method :|, :or
    end
end
