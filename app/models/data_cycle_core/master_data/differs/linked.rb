# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Linked < UuidSet
        def diff(a, b, _template, _partial_update)
          ids_a = parse_uuids(a)
          ids_b = parse_uuids(b)
          @diff_hash = (
            (set_diff(ids_a, ids_b) || []) +
            (order_change(ids_a, ids_b) || [])
          ).compact.presence
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
