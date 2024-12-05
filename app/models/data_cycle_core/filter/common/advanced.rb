# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Advanced
        COMPARISON_OPERATORS = {
          greater: '>',
          lower: '<',
          equal: '=',
          not_equal: '<>'
        }.freeze

        DATE_RANGE_COMPARISON_OPERATORS = {
          overlaps: '&&',
          contains: '@>'
        }.freeze

        def advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"equals_advanced_#{attribute_path}") ? :"equals_advanced_#{attribute_path}" : :"equals_advanced_#{type}"
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def not_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"not_equals_advanced_#{attribute_path}") ? :"not_equals_advanced_#{attribute_path}" : :"not_equals_advanced_#{type}"
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        alias equals_advanced_attributes advanced_attributes
        alias not_equals_advanced_attributes not_advanced_attributes

        def like_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"like_advanced_#{attribute_path}") ? :"like_advanced_#{attribute_path}" : :"like_advanced_#{type}"
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def not_like_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"not_like_advanced_#{attribute_path}") ? :"not_like_advanced_#{attribute_path}" : :"not_like_advanced_#{type}"
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def exists_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"exists_advanced_#{attribute_path}") ? :"exists_advanced_#{attribute_path}" : :"exists_advanced_#{type}"
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def not_exists_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"not_exists_advanced_#{attribute_path}") ? :"not_exists_advanced_#{attribute_path}" : :"not_exists_advanced_#{type}"
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def greater_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"greater_advanced_#{attribute_path}") ? :"greater_advanced_#{attribute_path}" : :"greater_advanced_#{type}"
          raise 'Unknown advanced_attribute search' unless respond_to?(advanced_type)
          send(advanced_type, value, attribute_path)
        end

        def lower_advanced_attributes(value = nil, type = nil, attribute_path = nil)
          advanced_type = respond_to?(:"lower_advanced_#{attribute_path}") ? :"lower_advanced_#{attribute_path}" : :"lower_advanced_#{type}"
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

        alias min_advanced_attributes advanced_attributes
        alias max_advanced_attributes advanced_attributes

        alias not_min_advanced_attributes not_advanced_attributes
        alias not_max_advanced_attributes not_advanced_attributes

        alias min_advanced_date equals_advanced_date
        alias max_advanced_date equals_advanced_date

        def not_equals_advanced_date(value = nil, attribute_path = nil)
          advanced_date(value, attribute_path, :not_equal)
        end

        def equals_advanced_date_range(value = nil, attribute_path = nil)
          advanced_date_range(value, attribute_path, :equal)
        end

        def not_equals_advanced_date_range(value = nil, attribute_path = nil)
          advanced_date_range(value, attribute_path, :not_equal)
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

        def not_like_advanced_string(value = nil, attribute_path = nil)
          advanced_string(value, attribute_path, :not_like)
        end

        def exists_advanced_string(value = nil, attribute_path = nil)
          advanced_string(value, attribute_path, :exists)
        end

        def not_exists_advanced_string(value = nil, attribute_path = nil)
          advanced_string(value, attribute_path, :not_exists)
        end

        def equals_advanced_slug(value = nil, _attribute_path = nil)
          reflect(
            @query.where(
              DataCycleCore::Thing::Translation.where(
                thing_translations[:slug].eq(value[:equals])
                  .and(thing_alias[:id].eq(thing_translations[:thing_id]))
              ).arel.exists
            )
          )
        end

        def equals_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }
          search_value = value['text']
          reflect(
            @query.where(
              DataCycleCore::Thing::Translation.where(
                in_json(thing_translations[:content], 'name').matches(search_value.downcase.to_s)
                  .and(thing_translations[:locale].in(@locale))
                  .and(thing_alias[:id].eq(thing_translations[:thing_id]))
              ).arel.exists
            )
          )
        end

        def not_equals_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }
          search_value = value['text']
          reflect(
            @query.where.not(
              DataCycleCore::Thing::Translation.where(
                in_json(thing_translations[:content], 'name').matches(search_value.downcase.to_s)
                  .and(thing_translations[:locale].in(@locale))
                  .and(thing_alias[:id].eq(thing_translations[:thing_id]))
              ).arel.exists
            )
          )
        end

        def like_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }
          search_value = value['text']
          reflect(
            @query.where(
              DataCycleCore::Thing::Translation.where(
                in_json(thing_translations[:content], 'name').matches("%#{search_value}%")
                  .and(thing_translations[:locale].in(@locale))
                  .and(thing_alias[:id].eq(thing_translations[:thing_id]))
              ).arel.exists
            )
          )
        end

        def not_like_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }
          search_value = value['text']
          reflect(
            @query.where.not(
              DataCycleCore::Thing::Translation.where(
                in_json(thing_translations[:content], 'name').matches("%#{search_value}%")
                  .and(thing_translations[:locale].in(@locale))
                  .and(thing_alias[:id].eq(thing_translations[:thing_id]))
              ).arel.exists
            )
          )
        end

        def exists_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }
          reflect(
            @query.where.not(
              DataCycleCore::Thing::Translation.where(
                in_json(thing_translations[:content], 'name').eq(nil)
                  .and(thing_translations[:locale].in(@locale))
                  .and(thing_alias[:id].eq(thing_translations[:thing_id]))
              ).arel.exists
            )
          )
        end

        def not_exists_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }
          reflect(
            @query.where(
              DataCycleCore::Thing::Translation.where(
                in_json(thing_translations[:content], 'name').eq(nil)
                  .and(thing_translations[:locale].in(@locale))
                  .and(thing_alias[:id].eq(thing_translations[:thing_id]))
              ).arel.exists
            )
          )
        end

        def equals_advanced_classification_alias_ids(value = nil, attribute_path = nil)
          advanced_classification_alias_ids(value, attribute_path, :equals)
        end

        def not_equals_advanced_classification_alias_ids(value = nil, attribute_path = nil)
          advanced_classification_alias_ids(value, attribute_path, :not_equals)
        end

        def exists_advanced_classification_alias_ids(value = nil, attribute_path = nil)
          advanced_classification_alias_ids(value, attribute_path, :exists)
        end

        def not_exists_advanced_classification_alias_ids(value = nil, attribute_path = nil)
          advanced_classification_alias_ids(value, attribute_path, :not_exists)
        end

        private

        def advanced_classification_alias_ids(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.present? && attribute_path.present? && comparison.present?

          attribute_path_exists = true

          case comparison
          when :exists
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil != \'[]\' AND pil IS NOT NULL)', attribute_path])
          when :not_exists
            attribute_path_exists = false
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil = \'[]\' OR pil IS NULL)', attribute_path])
          when :equals
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['ARRAY(SELECT jsonb_array_elements_text(searches.advanced_attributes -> ?))::uuid[] && ARRAY[?]::uuid[]', attribute_path, value])
          when :not_equals
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['NOT(ARRAY(SELECT jsonb_array_elements_text(searches.advanced_attributes -> ?))::uuid[] && ARRAY[?]::uuid[])', attribute_path, value])
          else
            return self
          end

          advanced_query(query_string, attribute_path, attribute_path_exists)
        end

        def advanced_numeric(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?
          num_range = "[#{value&.dig('min').presence&.to_f},#{value&.dig('max').presence&.to_f}]"

          case comparison
          when :equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements(searches.advanced_attributes -> ?) pil WHERE ?::numrange @> (pil)::decimal)', attribute_path, num_range])
          when :not_equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['NOT(EXISTS(SELECT FROM jsonb_array_elements(searches.advanced_attributes -> ?) pil WHERE ?::numrange @> (pil)::decimal))', attribute_path, num_range])
          else
            return self
          end

          advanced_query(query_string, attribute_path)
        end

        def advanced_date(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?
          date_range = "[#{value&.dig('from')&.to_s},#{value&.dig('until')&.to_s}]"

          case comparison
          when :equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::daterange @> (pil)::text::date)', attribute_path, date_range])
          when :not_equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['NOT(EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::daterange @> (pil)::text::date))', attribute_path, date_range])
          else
            return self
          end

          advanced_query(query_string, attribute_path)
        end

        def advanced_date_range(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?
          date_range = "[#{value&.dig('from')&.to_s},#{value&.dig('until')&.to_s}]"

          interval_keys = DataCycleCore::Feature::AdvancedFilter.available_advanced_attribute_filters.dig(attribute_path, 'attribute_keys')
          query_operator = DATE_RANGE_COMPARISON_OPERATORS[DataCycleCore::Feature::AdvancedFilter.available_advanced_attribute_filters.dig(attribute_path, 'query_operator')&.to_sym || :overlaps]

          case comparison
          when :equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["?::daterange #{query_operator} CONCAT('[',(advanced_attributes ->> ?)::text::date,',',(advanced_attributes ->> ?)::text::date,']')::daterange", date_range, interval_keys&.first, interval_keys&.second])
          when :not_equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["NOT(?::daterange #{query_operator} CONCAT('[',(advanced_attributes ->> ?)::text::date,',',(advanced_attributes ->> ?)::text::date,']')::daterange)", date_range, interval_keys&.first, interval_keys&.second])
          else
            return self
          end

          advanced_query(query_string, attribute_path, false, true)
        end

        def advanced_time(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.present? && attribute_path.present? && comparison.present?
          comparison_operator = COMPARISON_OPERATORS[comparison]
          query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::text::time #{comparison_operator} ?::time)", attribute_path, value])

          advanced_query(query_string, attribute_path)
        end

        def advanced_boolean(value = nil, attribute_path = nil, comparison = nil)
          return self unless (value.present? || value.to_s == 'false') && attribute_path.present? && comparison.present?

          comparison_operator = COMPARISON_OPERATORS[comparison]
          query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["EXISTS(SELECT FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::boolean #{comparison_operator} ?)", attribute_path, value])
          advanced_query(query_string, attribute_path)
        end

        def advanced_string(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?
          search_value = value['text']
          attribute_path_exists = true

          case comparison
          when :exists
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil != \'\' AND pil IS NOT NULL)', attribute_path])
          when :not_exists
            attribute_path_exists = false
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil = \'\' OR pil IS NULL)', attribute_path])
          when :equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil = ?)', attribute_path, search_value])
          when :not_equal
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['NOT(EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil = ?))', attribute_path, search_value])
          when :like
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil ILIKE ?)', attribute_path, "%#{search_value&.split&.join('%')}%"])
          when :not_like
            query_string = ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['NOT(EXISTS(SELECT FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil ILIKE ?))', attribute_path, "%#{search_value&.split&.join('%')}%"])
          else
            return self
          end
          advanced_query(query_string, attribute_path, attribute_path_exists)
        end

        def advanced_query(query_string, attribute_path, attribute_path_exists = true, skip_attribute_exists_query = false)
          reflect(
            @query
              .where(
                search_exists(
                  Arel.sql(advanced_query_string(query_string, attribute_path, attribute_path_exists, skip_attribute_exists_query))
                )
              )
          )
        end

        def advanced_query_string(query_string, attribute_path, attribute_path_exists, skip_attribute_exists_query)
          return query_string if skip_attribute_exists_query
          return [attribute_path_exists(attribute_path), query_string].compact_blank.join(' AND ').prepend('(').concat(')') if attribute_path_exists == true
          [attribute_path_not_exists(attribute_path), query_string].compact_blank.join(' OR ').prepend('(').concat(')')
        end

        def attribute_path_exists(path)
          ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['jsonb_path_exists(advanced_attributes, :path)', {path: "$.\"#{path}\""}])
        end

        def attribute_path_not_exists(path)
          ActiveRecord::Base.send(:sanitize_sql_for_conditions, ['NOT(jsonb_path_exists(advanced_attributes, :path))', {path: "$.\"#{path}\""}])
        end
      end
    end
  end
end
