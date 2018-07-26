# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class BasicDiffer
        attr_reader :diff_hash

        def initialize(a, b, template = nil, parent_key = '')
          @diff_hash = nil
          @parent_key = parent_key
          diff(a, b, template)
        end

        def diff(a, b, template)
        end

        private

        def basic_diff(a, b)
          return if a == b
          return ['+', b] if a.blank? && !a.is_a?(FalseClass)
          return ['-', a] if b.blank?
          ['~', a, b]
        end
      end
    end
  end
end
