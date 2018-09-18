# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Calculate
      module Math
        class << self
          def sum(a, b)
            return if a.nil? || b.nil?
            a + b
          end
        end
      end
    end
  end
end
