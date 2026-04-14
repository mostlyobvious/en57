# frozen_string_literal: true

# rbs_inline: enabled

module En57
  # @rbs!
  #   interface _Event
  #     def type: () -> String
  #     def data: () -> untyped
  #   end

  Event = Data.define(:type, :data)
end
