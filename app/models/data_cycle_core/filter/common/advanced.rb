# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Advanced
        COMPARISION_OPERATORS = {
          greater: '>',
          lower: '<',
          equal: '=',
          not_equal: '<>'
        }.freeze

        def greater_advanced_numeric(value = nil, attribute_path = nil)
          advanced_numeric(value, attribute_path, :greater)
        end

        def lower_advanced_numeric(value = nil, attribute_path = nil)
          advanced_numeric(value, attribute_path, :lower)
        end

        def equals_advanced_numeric(value = nil, attribute_path = nil)
          advanced_numeric(value, attribute_path, :equal)
        end

        def not_equals_advanced_numeric(value = nil, attribute_path = nil)
          advanced_numeric(value, attribute_path, :not_equal)
        end

        def greater_advanced_date(value = nil, attribute_path = nil)
          advanced_date(value, attribute_path, :greater)
        end

        def lower_advanced_date(value = nil, attribute_path = nil)
          advanced_date(value, attribute_path, :lower)
        end

        def equals_advanced_date(value = nil, attribute_path = nil)
          advanced_date(value, attribute_path, :equal)
        end

        def not_equals_advanced_date(value = nil, attribute_path = nil)
          advanced_date(value, attribute_path, :not_equal)
        end

        def greater_advanced_time(value = nil, attribute_path = nil)
          advanced_time(value, attribute_path, :greater)
        end

        def lower_advanced_time(value = nil, attribute_path = nil)
          advanced_time(value, attribute_path, :lower)
        end

        def equals_advanced_time(value = nil, attribute_path = nil)
          advanced_time(value, attribute_path, :equal)
        end

        def not_equals_advanced_time(value = nil, attribute_path = nil)
          advanced_time(value, attribute_path, :not_equal)
        end

        def equals_advanced_boolean(value = nil, attribute_path = nil)
          advanced_boolean(value, attribute_path, :equal)
        end

        def not_equals_advanced_boolean(value = nil, attribute_path = nil)
          advanced_boolean(value, attribute_path, :not_equal)
        end

        private

        def advanced_numeric(value = nil, attribute_path = nil, comparision = nil)
          return self unless value.present? && attribute_path.present? && comparision.present?

          comparision_operator = COMPARISION_OPERATORS.dig(comparision)
          query_string = Thing.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::decimal #{comparision_operator} ?)", attribute_path, value.to_f])

          reflect(
            @query.where(attribute_path_not_null(attribute_path)).where(query_string)
          )
        end

        def advanced_time(value = nil, attribute_path = nil, comparision = nil)
          return self unless value.present? && attribute_path.present? && comparision.present?
          comparision_operator = COMPARISION_OPERATORS.dig(comparision)
          query_string = Thing.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::text::time #{comparision_operator} ?::time)", attribute_path, value])

          reflect(
            @query.where(attribute_path_not_null(attribute_path)).where(query_string)
          )
        end

        def advanced_date(value = nil, attribute_path = nil, comparision = nil)
          return self unless value.present? && attribute_path.present? && comparision.present?
          comparision_operator = COMPARISION_OPERATORS.dig(comparision)
          query_string = Thing.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::text::date #{comparision_operator} ?::date)", attribute_path, value])

          reflect(
            @query.where(attribute_path_not_null(attribute_path)).where(query_string)
          )
        end

        def advanced_boolean(value = nil, attribute_path = nil, comparision = nil)
          return self unless (value.present? || value.to_s == 'false') && attribute_path.present? && comparision.present?

          comparision_operator = COMPARISION_OPERATORS.dig(comparision)
          query_string = Thing.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::boolean #{comparision_operator} ?)", attribute_path, value])

          reflect(
            @query.where(attribute_path_not_null(attribute_path)).where(query_string)
          )
        end

        def attribute_path_not_null(path)
          Thing.send(:sanitize_sql_for_conditions, ['advanced_attributes ? :path', path: path])
        end
      end
    end
  end
end
