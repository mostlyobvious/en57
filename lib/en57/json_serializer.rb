# frozen_string_literal: true

# rbs_inline: enabled

require "json"

module En57
  # @rbs!
  #   interface _Serializer
  #     def dump: (untyped) -> [String, untyped]
  #     def load: (String, untyped) -> untyped
  #   end

  class JsonSerializer
    #: (untyped payload) -> [String, untyped]
    def dump(payload)
      [JSON.generate(payload), {}]
    end

    #: (String string, untyped description) -> untyped
    def load(string, description)
      JSON.parse(string)
    end
  end
end
