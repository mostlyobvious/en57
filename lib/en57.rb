# frozen_string_literal: true

require_relative "en57/version"
require_relative "en57/event"
require_relative "en57/json_serializer"
require_relative "en57/query"
require_relative "en57/scope"
require_relative "en57/pg_adapter"
require_relative "en57/sequel_adapter" if defined?(Sequel)
require_relative "en57/active_record_adapter" if defined?(ActiveRecord)
require_relative "en57/repository"
require_relative "en57/event_store"

module En57
  AppendConditionViolated = Class.new(StandardError)
end
