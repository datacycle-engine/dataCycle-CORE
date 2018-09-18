# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Calculate
      module Math
        class << self
          def sum(*a)
            a.select { |v| v.is_a?(::Numeric) }.try(:sum)
          end
        end
      end
    end
  end
end
