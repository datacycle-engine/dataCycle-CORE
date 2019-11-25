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

        def advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = "equals_advanced_#{type}".to_sym
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def not_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = "not_equals_advanced_#{type}".to_sym
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def like_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = "like_advanced_#{type}".to_sym
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        # TODO: check if required in future version
        def greater_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = "greater_advanced_#{type}".to_sym
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        # TODO: check if required in future version
        def lower_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = "lower_advanced_#{type}".to_sym
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def equals_advanced_numeric(value = nil, attribute_path = nil)
          advanced_numeric(value, attribute_path, :equal)
        end

        def not_equals_advanced_numeric(value = nil, attribute_path = nil)
          advanced_numeric(value, attribute_path, :not_equal)
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

        def equals_advanced_string(value = nil, attribute_path = nil)
          advanced_string(value, attribute_path, :equal)
        end

        def not_equals_advanced_string(value = nil, attribute_path = nil)
          advanced_string(value, attribute_path, :not_equal)
        end

        def like_advanced_string(value = nil, attribute_path = nil)
          advanced_string(value, attribute_path, :like)
        end

        private

        def advanced_numeric(value = nil, attribute_path = nil, comparision = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparision.present?
          num_range = "[#{value&.dig('min').presence&.to_f},#{value&.dig('max').presence&.to_f}]"

          case comparision
          when :equal
            query_string = Thing.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::numrange @> (pil)::decimal)', attribute_path, num_range])
          when :not_equal
            query_string = Thing.send(:sanitize_sql_for_conditions, ['NOT(EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::numrange @> (pil)::decimal))', attribute_path, num_range])
          else
            return self
          end

          reflect(
            @query.where(attribute_path_not_null(attribute_path)).where(query_string)
          )
        end

        def advanced_date(value = nil, attribute_path = nil, comparision = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparision.present?
          date_range = "[#{value&.dig('from')&.to_s},#{value&.dig('until')&.to_s}]"
          query_string = Thing.send(:sanitize_sql_for_conditions, ["?::daterange @> (things.#{attribute_path})::date", date_range])

          case comparision
          when :equal
            query_string = Thing.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::daterange @> (pil)::text::date)', attribute_path, date_range])
          when :not_equal
            query_string = Thing.send(:sanitize_sql_for_conditions, ['NOT(EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::daterange @> (pil)::text::date))', attribute_path, date_range])
          else
            return self
          end

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

        def advanced_boolean(value = nil, attribute_path = nil, comparision = nil)
          return self unless (value.present? || value.to_s == 'false') && attribute_path.present? && comparision.present?

          comparision_operator = COMPARISION_OPERATORS.dig(comparision)
          query_string = Thing.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::boolean #{comparision_operator} ?)", attribute_path, value])

          reflect(
            @query.where(attribute_path_not_null(attribute_path)).where(query_string)
          )
        end

        def advanced_string(value = nil, attribute_path = nil, comparision = nil)
          return self unless value.present? && attribute_path.present? && comparision.present?

          case comparision
          when :equal
            query_string = Thing.send(:sanitize_sql_for_conditions, ['(advanced_attributes -> :attribute_path)::jsonb ? :value', attribute_path: attribute_path, value: value])
          when :not_equal
            query_string = Thing.send(:sanitize_sql_for_conditions, ['NOT(advanced_attributes -> :attribute_path)::jsonb ? :value', attribute_path: attribute_path, value: value])
          when :like
            query_string = Thing.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::TEXT LIKE ?)', attribute_path, "%#{value}%"])
          else
            return self
          end

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
