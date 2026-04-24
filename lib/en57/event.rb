# frozen_string_literal: true

require "securerandom"

module En57
  Event =
    Data.define(:id, :type, :data, :tags) do
      def initialize(id: SecureRandom.uuid_v7, type:, data: {}, tags: [])
        super(id:, type:, data:, tags:)
      end
    end
end
