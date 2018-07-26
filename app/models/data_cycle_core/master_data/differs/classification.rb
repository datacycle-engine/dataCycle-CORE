# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Classification < BasicDiffer
        def diff(a, b, _template)
          class_a = parse_classification(a)
          class_b = parse_classification(b)
          @diff_hash = class_diff(class_a, class_b)
        end

        private

        def class_diff(a, b)
          return if a == b
          return [['-', a]] if b.blank?
          return [['+', b]] if a.blank?
          new_class = b - a
          del_class = a - b
          new_items = nil
          new_items = ['+', new_class] if new_class.size.positive?
          del_items = nil
          del_items = ['-', del_class] if del_class.size.positive?
          [new_items, del_items].compact.presence
        end

        def parse_classification(a)
          return if a.blank?
          data = a.is_a?(::String) ? [a] : a
          data = a&.ids if data.is_a?(ActiveRecord::Relation)
          raise ArgumentError, 'expected a uuid or list of uuids' unless data.is_a?(::Array)
          data.sort
        end
      end
    end
  end
end
