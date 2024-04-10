# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Collection < UuidSet
        def diff(a, b, _template, _partial_update)
          ids_a = parse_uuids(a)
          ids_b = parse_uuids(b)
          @diff_hash = (
            set_diff(ids_a, ids_b) || []
          ).compact.presence
        end

        private

        def set_diff(a, b)
          return if a.to_set == b.to_set
          return [['-', a]] if b.blank?
          return [['+', b]] if a.blank?
          new_items = b - a
          del_items = a - b
          new_record = nil
          new_record = ['+', new_items&.sort] if new_items.size.positive?
          del_record = nil
          del_record = ['-', del_items&.sort] if del_items.size.positive?
          [new_record, del_record].compact.presence
        end
      end
    end
  end
end
