# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Basic
        attr_reader :diff_hash

        def initialize(a, b, template = nil, parent_key = '', partial_update = false)
          @diff_hash = nil
          @parent_key = parent_key
          diff(a, b, template, partial_update)
        end

        def diff(a, b, _template, _partial_update)
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

        def blank?(data)
          DataCycleCore::DataHashService.blank?(data)
        end

        # def load_value(default_value)
        #   return if default_value.blank?
        #   if default_value.is_a?(::String) && /{{.*}}/.match?(default_value)
        #     eval(default_value[2..-3]) # rubocop:disable Security/Eval
        #   else
        #     default_value
        #   end
        # end
      end
    end
  end
end
