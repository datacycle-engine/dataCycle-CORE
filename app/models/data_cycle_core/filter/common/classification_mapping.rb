# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module ClassificationMapping
        def experimental_classification_alias_ids(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[] OR classification_ancestors_mapping && ARRAY[?]::uuid[]', ids, ids])
          reflect(
            @query.where(query_string)
          )
        end

        def experimental_not_classification_alias_ids(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[] OR classification_ancestors_mapping && ARRAY[?]::uuid[]', ids, ids])
          reflect(
            @query.where.not(query_string)
          )
        end
      end
    end
  end
end
