# frozen_string_literal: true

require "test_helper"

module En57
  class TestEn57 < Minitest::Test
    cover En57

    def test_that_it_has_a_version_number
      refute_nil VERSION
    end
  end
end
