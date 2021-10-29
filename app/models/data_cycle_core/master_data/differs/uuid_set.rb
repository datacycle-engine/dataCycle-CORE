# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class UuidSet < Basic
        def diff(a, b, _template, _partial_update)
          ids_a = parse_uuids(a)
          ids_b = parse_uuids(b)
          @diff_hash = set_diff(ids_a&.sort, ids_b&.sort)
        end

        private

        def set_diff(a, b)
          return if a == b
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

        def parse_uuid(a)
          return if a.blank?
          a.is_a?(ActiveRecord::Base) ? a&.id : a
        end

        def parse_uuids(a)
          return [] if a.blank?
          data = a.is_a?(::String) ? [a] : a
          data = a&.ids if data.is_a?(ActiveRecord::Relation)
          raise ArgumentError, 'expected a uuid or list of uuids' unless data.is_a?(::Array)
          data
        end
      end
    end
  end
end
