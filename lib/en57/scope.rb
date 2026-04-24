# frozen_string_literal: true

module En57
  EmptyScope =
    Data.define do
      def to_query = Query.all
    end

  MergedScope =
    Data.define(:repository, :query) do
      def each(&block)
        return enum_for unless block

        repository.read(query).each(&block)
      end

      def to_query = query

      def or(other)
        self.class.new(repository:, query: query.or(other.to_query))
      end
      alias_method :|, :or
    end

  Scope =
    Data.define(:repository, :query) do
      def each(&block)
        return enum_for unless block

        repository.read(query).each(&block)
      end

      def to_query = query

      def with_tag(*tags)
        with(query: query.refine_last { |item| item.with_tags(tags) })
      end

      def of_type(*types)
        with(query: query.refine_last { |item| item.with_types(types) })
      end

      def or(other)
        MergedScope.new(repository:, query: query.or(other.to_query))
      end
      alias_method :|, :or
    end
end
