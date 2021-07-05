# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Number < Basic
        def number_formats
          ['integer', 'float']
        end

        def epsilon
          1e-3
        end

        def diff(a, b, template, _partial_update)
          return if a.blank? && b.blank?
          format_key = template&.dig('validations', 'format')
          a_value = a
          b_value = b
          if format_key.present? && number_formats.include?(format_key)
            @diff_hash = method(format_key).call(a_value, b_value)
          else
            @diff_hash = float(a_value, b_value)
          end
          diff_hash
        end

        private

        def integer(a, b)
          int_a = a&.to_i
          int_b = b&.to_i
          basic_diff(int_a, int_b)
        end

        def float(a, b)
          float_a = a&.to_f
          float_b = b&.to_f
          return ['+', float_b] if a.blank?
          return ['-', float_a] if b.blank?
          return if (float_a - float_b).abs < epsilon
          ['~', float_a, float_b]
        end
      end
    end
  end
end
