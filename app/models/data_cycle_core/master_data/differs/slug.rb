# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Slug < Basic
        def diff(a, b, _template, _partial_update)
          string_a = a&.to_slug
          string_b = b&.to_slug
          @diff_hash = basic_diff(string_a, string_b)
        end
      end
    end
  end
end
