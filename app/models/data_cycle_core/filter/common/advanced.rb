# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Advanced
        def greater_advanced_numeric(value = nil, attribute_path = nil)
          return self unless value.present? && attribute_path.present?

          v = value.to_f
          query_string = Thing.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::decimal > ?)", attribute_path, v])

          reflect(
            @query.where(attribute_path_not_null(attribute_path)).where(query_string)
          )
        end

        private

        def attribute_path_not_null(path)
          Thing.send(:sanitize_sql_for_conditions, ["advanced_attributes->>? IS NOT NULL", path])
        end
      end
    end
  end
end
