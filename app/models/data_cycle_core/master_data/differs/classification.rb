# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Classification < UuidSet
        def diff(a, b, template)
          ids_a = parse_uuids(a)
          ids_b = parse_uuids(b)
          ids_a += add_default_value(ids_a, template)
          ids_b += add_default_value(ids_b, template)
          @diff_hash = set_diff(ids_a&.sort, ids_b&.sort)
        end

        private

        def add_default_value(a, template)
          return [] if a.present? || template&.dig('default_value').blank?
          default_value_id = DataCycleCore::Classification
            .joins(classification_aliases: [classification_tree: [:classification_tree_label]])
            .where(classification_tree_labels: { name: template.dig('tree_label') })
            .where(classification_aliases: { name: template.dig('default_value') })
            .first!
            .id
          [default_value_id]
        end
      end
    end
  end
end
