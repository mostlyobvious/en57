# frozen_string_literal: true

module En57
  Query =
    Data.define(:items) do
      def self.all = new(items: [])
    end
end
