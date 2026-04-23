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
  end
end
