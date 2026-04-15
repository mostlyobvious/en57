# frozen_string_literal: true

module En57
  class EventStore
    def initialize(repository)
      @repository = repository
    end

    def append(events)
      @repository.append(events)
    end

    def read
      @repository.read
    end
  end
end
