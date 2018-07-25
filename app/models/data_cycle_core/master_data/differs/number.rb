# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Number < BasicDiffer
        def number_formats
          ['integer', 'float']
        end

        def diff(a, b, template)
          return if a.blank? && b.blank?
          format_key = template&.dig('validations', 'format')
          if format_key.present? && number_formats.include?(format_key)
            @diff_hash = method(format_key).call(a, b)
          else
            @diff_hash = float(a, b)
          end
          diff_hash
        end

        private

        def integer(a, b)
          return if a == b
          return ['+', b] if a.blank?
          return ['-', a] if b.blank?
          ['~', a, b]
        end

        def float(a, b)
          return ['+', b] if a.blank?
          return ['-', a] if b.blank?
          epsilon = 1e-6
          return if (a - b).abs < epsilon
          ['~', a, b]
        end
      end
    end
  end
end
