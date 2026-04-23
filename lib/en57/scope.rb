# frozen_string_literal: true

module En57
  class Scope
    def initialize(repository, query)
      @repository = repository
      @query = query
    end

    def each(&block)
      return enum_for unless block

      @repository.read(@query).each(&block)
    end

    def with_tag(**tags)
      self.class.new(
        @repository,
        @query.refine_last { |item| item.with_tags(tags) },
      )
    end

    def of_type(*types)
      self.class.new(
        @repository,
        @query.refine_last { |item| item.with_types(types) },
      )
    end
  end
end
