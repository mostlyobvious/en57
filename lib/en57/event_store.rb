# frozen_string_literal: true

module En57
  class EventStore
    def initialize(repository)
      @repository = repository
    end

    def append(events, **options)
      @repository.append(events, **options)
      self
    end

    def read
      Scope.new(@repository, Query.all)
    end
  end
end
