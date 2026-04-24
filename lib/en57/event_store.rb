# frozen_string_literal: true

module En57
  class EventStore
    def initialize(repository)
      @repository = repository
    end

    def append(events, fail_if: EmptyScope.new, after: nil)
      @repository.append(events, fail_if: fail_if.to_query, after:)
      self
    end

    def read
      Scope.new(@repository, Query.all)
    end
  end
end
