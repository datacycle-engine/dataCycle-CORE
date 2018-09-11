# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Basic
        attr_reader :diff_hash

        def initialize(a, b, template = nil, parent_key = '')
          @diff_hash = nil
          @parent_key = parent_key
          diff(a, b, template)
        end

        def diff(a, b, _template)
          @diff_hash = basic_diff(a, b)
        end

        private

        def basic_diff(a, b)
          generic_diff(a, b, ->(x, y) { x == y })
        end

        def generic_diff(a, b, cmp)
          return if cmp.call(a, b)
          return ['+', b] if a.blank? && !a.is_a?(FalseClass)
          return ['-', a] if b.blank?
          ['~', a, b]
        end
      end
    end
  end
end
