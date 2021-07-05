# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Classification < UuidSet
        def diff(a, b, _template, _partial_update)
          ids_a = parse_uuids(a)
          ids_b = parse_uuids(b)
          # ids_a += [add_default_value(ids_a, template)].compact
          # ids_b += [add_default_value(ids_b, template)].compact
          @diff_hash = set_diff(ids_a&.sort, ids_b&.sort)
        end

        # def add_default_value(a, template)
        #   return if a.present? || template&.dig('default_value').blank?
        #   DataCycleCore::ClassificationAlias.classification_for_tree_with_name(template.dig('tree_label'), template.dig('default_value'))
        # end
      end
    end
  end
end
