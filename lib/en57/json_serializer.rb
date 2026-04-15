# frozen_string_literal: true

require "json"

module En57
  class JsonSerializer
    IDENTITY = lambda { it }

    def initialize
      @registry = [
        [Symbol, IDENTITY, lambda { it.to_sym }],
        [String, IDENTITY, IDENTITY],
      ]
    end

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
