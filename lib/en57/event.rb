# frozen_string_literal: true

module En57
  Event =
    Data.define(:id, :type, :data, :tags) do
      def initialize(id:, type:, data:, tags: {})
        super(id:, type:, data:, tags:)
      end
    end
end
