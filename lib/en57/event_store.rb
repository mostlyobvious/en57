# frozen_string_literal: true

# rbs_inline: enabled

module En57
  class EventStore
    #: (untyped repository) -> void
    def initialize(repository)
      @repository = repository
    end

    #: (Array[_Event] events) -> void
    def append(events)
      @repository.append(events)
    end

    #: () -> Array[Event]
    def read
      @repository.read
    end
  end
end
