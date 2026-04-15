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
    IDENTITY = lambda { it }

    def initialize
      @registry = [
        [Symbol, IDENTITY, lambda { it.to_sym }],
        [String, IDENTITY, IDENTITY],
      ]
    end

    #: (untyped payload) -> [String, untyped]
    def dump(payload)
      [
        JSON.generate(payload),
        JSON.generate(
          {
            "keys" =>
              payload.reduce({}) do |acc, (k, v)|
                @registry.reduce(acc) do |acc, (serializer, dump, _)|
                  if serializer === k
                    acc.merge(dump[k] => serializer)
                  else
                    acc
                  end
                end
              end,
          },
        ),
      ]
    end

    #: (String string, untyped description) -> untyped
    def load(string, description)
      JSON
        .parse(description)
        .fetch("keys")
        .reduce(
          JSON.parse(string),
        ) do |deserialized, (description_key, original_type)|
          @registry.reduce(
            deserialized,
          ) do |deserialized, (serializer, _, load)|
            if serializer.name == original_type
              deserialized.merge(
                load[description_key] => deserialized.delete(description_key),
              )
            else
              deserialized
            end
          end
        end
    end
  end
end
