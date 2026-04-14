# frozen_string_literal: true

# rbs_inline: enabled

require "json"

module En57
  # @rbs!
  #   interface _Serializer
  #     def dump: (untyped) -> String
  #     def load: (String) -> untyped
  #   end

  class JsonSerializer
    #: (untyped payload) -> String
    def dump(payload)
      JSON.generate(payload)
    end

    #: (String string) -> untyped
    def load(string)
      JSON.parse(string)
    end
  end
end
