# frozen_string_literal: true

# rbs_inline: enabled

require "json"

module En57
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
