# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Linked < UuidArray
        def diff(a, b, _template)
          class_a = parse_uuids(a)
          class_b = parse_uuids(b)
          @diff_hash = ((array_diff(class_a, class_b) || []) + (order_change(class_a, class_b) || [])).compact.presence
        end

        private

        def order_change(a, b)
          return if a.blank? || b.blank?
          x = a.dup
          y = b.dup
          change = []
          (0..(x.size - 1)).each do |i|
            j = y.find_index(x[i])
            next if j.nil? || j == i
            change << ['<', x[i], i, j] if j < i
            change << ['>', x[i], i, j] if j > i
          end
          change.presence
        end
      end
    end
  end
end
