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

        alias equals_advanced_number equals_advanced_numeric

        def not_equals_advanced_numeric(value = nil, attribute_path = nil)
          advanced_numeric(value, attribute_path, :not_equal)
        end

        alias not_equals_advanced_number not_equals_advanced_numeric

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

        def not_equals_advanced_boolean(value = nil, attribute_path = nil)
          advanced_boolean(value, attribute_path, :not_equal)
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
              DataCycleCore::Thing::Translation
                .where(slug: value[:equals])
                .where(thing[:id].eq(thing_translations[:thing_id]))
                .select(1)
                .arel.exists
            )
          )
        end

        def equals_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }

          search_value = value['text']

          reflect(@query.where(tt_exists_subquery(search_value.downcase.to_s)))
        end

        def not_equals_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }

          search_value = value['text']

          reflect(@query.where.not(tt_exists_subquery(search_value.downcase.to_s)))
        end

        def like_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }

          search_value = value['text']

          reflect(@query.where(tt_exists_subquery("%#{search_value}%")))
        end

        def not_like_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }

          search_value = value['text']

          reflect(@query.where.not(tt_exists_subquery("%#{search_value}%")))
        end

        def exists_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }

          reflect(@query.where.not(tt_exists_subquery(nil)))
        end

        def not_exists_advanced_translated_name(value = nil, _attribute_path = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? }

          reflect(@query.where(tt_exists_subquery(nil)))
        end

        def equals_advanced_concept_ids(value = nil, attribute_path = nil)
          advanced_concept_ids(value, attribute_path, :equals)
        end

        def not_equals_advanced_concept_ids(value = nil, attribute_path = nil)
          advanced_concept_ids(value, attribute_path, :not_equals)
        end

        def exists_advanced_concept_ids(value = nil, attribute_path = nil)
          advanced_concept_ids(value, attribute_path, :exists)
        end

        def not_exists_advanced_concept_ids(value = nil, attribute_path = nil)
          advanced_concept_ids(value, attribute_path, :not_exists)
        end

        private

        def tt_exists_subquery(value)
          base_query = DataCycleCore::Thing::Translation
            .where(thing[:id].eq(thing_translations[:thing_id]))
            .select(1)

          base_query = base_query.where(locale: @locale) if @locale.present?

          base_query = if value.nil?
                         base_query.where(in_json(thing_translations[:content], 'name').eq(nil))
                       else
                         base_query.where(in_json(thing_translations[:content], 'name').matches(value))
                       end

          base_query.arel.exists
        end

        def advanced_concept_ids(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.present? && attribute_path.present? && comparison.present?

          attribute_path_exists = true

          case comparison
          when :exists
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil != \'[]\' AND pil IS NOT NULL)', attribute_path])
          when :not_exists
            attribute_path_exists = false
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil = \'[]\' OR pil IS NULL)', attribute_path])
          when :equals
            query_string = advanced_classification_contains(attribute_path, value)
          when :not_equals
            query_string = sanitize_sql(['NOT(ARRAY(SELECT jsonb_array_elements_text(searches.advanced_attributes -> ?))::uuid[] && ARRAY[?]::uuid[])', attribute_path, value])
          else
            return self
          end

          advanced_query(query_string, attribute_path, attribute_path_exists)
        end

        def advanced_numeric(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?

          if value.key?('equals') || value.key?('not_equals')
            v = (value['equals'] || value['not_equals'])&.to_f
            num_range = "[#{v},#{v}]"
          else
            num_range = "[#{value&.dig('min').presence&.to_f},#{value&.dig('max').presence&.to_f}]"
          end

          case comparison
          when :equal
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements(searches.advanced_attributes -> ?) pil WHERE ?::numrange @> (pil)::decimal)', attribute_path, num_range])
          when :not_equal
            query_string = sanitize_sql(['NOT(EXISTS(SELECT 1 FROM jsonb_array_elements(searches.advanced_attributes -> ?) pil WHERE ?::numrange @> (pil)::decimal))', attribute_path, num_range])
          else
            return self
          end

          advanced_query(query_string, attribute_path)
        end

        def advanced_date(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?

          date_range = "[#{value&.dig('from')},#{value&.dig('until')}]"

          case comparison
          when :equal
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::daterange @> (pil)::text::date)', attribute_path, date_range])
          when :not_equal
            query_string = sanitize_sql(['NOT(EXISTS(SELECT 1 FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE ?::daterange @> (pil)::text::date))', attribute_path, date_range])
          else
            return self
          end

          advanced_query(query_string, attribute_path)
        end

        def advanced_date_range(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?

          date_range = "[#{value&.dig('from')},#{value&.dig('until')}]"

          interval_keys = DataCycleCore::Feature::AdvancedFilter.available_advanced_attribute_filters.dig(attribute_path, 'attribute_keys')
          query_operator = DATE_RANGE_COMPARISON_OPERATORS[DataCycleCore::Feature::AdvancedFilter.available_advanced_attribute_filters.dig(attribute_path, 'query_operator')&.to_sym || :overlaps]

          case comparison
          when :equal
            query_string = sanitize_sql(["?::daterange #{query_operator} CONCAT('[',(advanced_attributes ->> ?)::text::date,',',(advanced_attributes ->> ?)::text::date,']')::daterange", date_range, interval_keys&.first, interval_keys&.second])
          when :not_equal
            query_string = sanitize_sql(["NOT(?::daterange #{query_operator} CONCAT('[',(advanced_attributes ->> ?)::text::date,',',(advanced_attributes ->> ?)::text::date,']')::daterange)", date_range, interval_keys&.first, interval_keys&.second])
          else
            return self
          end

          advanced_query(query_string, attribute_path, false, true)
        end

        def advanced_time(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.present? && attribute_path.present? && comparison.present?

          comparison_operator = COMPARISON_OPERATORS[comparison]
          query_string = sanitize_sql(["EXISTS(SELECT 1 FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::text::time #{comparison_operator} ?::time)", attribute_path, value])

          advanced_query(query_string, attribute_path)
        end

        def advanced_boolean(value = nil, attribute_path = nil, comparison = nil)
          value = value[:bool] if value.is_a?(Hash)
          return self unless (value.present? || value.to_s == 'false') && attribute_path.present? && comparison.present?

          case comparison
          when :equal
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::boolean = ?)', attribute_path, value])
          when :not_equal
            query_string = sanitize_sql(['NOT(EXISTS(SELECT 1 FROM jsonb_array_elements(advanced_attributes -> ?) pil WHERE (pil)::boolean = ?))', attribute_path, value])
          else
            return self
          end

          advanced_query(query_string, attribute_path)
        end

        def advanced_string(value = nil, attribute_path = nil, comparison = nil)
          return self unless value.is_a?(Hash) && value.stringify_keys!.any? { |_, v| v.present? } && attribute_path.present? && comparison.present?

          search_value = value['text']&.split(',')&.map(&:strip) # not present for exists, not_exists

          attribute_path_exists = true

          case comparison
          when :exists
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil != \'\' AND pil IS NOT NULL)', attribute_path])
          when :not_exists
            attribute_path_exists = false
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil = \'\' OR pil IS NULL)', attribute_path])
          when :equal
            query_string = sanitize_sql(['EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil IN (?))', attribute_path, search_value])
          when :not_equal
            query_string = sanitize_sql(['NOT(EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE pil IN (?)))', attribute_path, search_value])
          when :like
            like_clauses = search_value.map do |val|
              sanitize_sql(['pil ILIKE ?', "%#{val&.split&.join('%')}%"])
            end
            query_string = sanitize_sql(["EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE #{like_clauses.join(' OR ')})", attribute_path])
          when :not_like
            like_clauses = search_value.map do |val|
              sanitize_sql(['pil ILIKE ?', "%#{val&.split&.join('%')}%"])
            end
            query_string = sanitize_sql(["NOT(EXISTS(SELECT 1 FROM jsonb_array_elements_text(advanced_attributes -> ?) pil WHERE #{like_clauses.join(' OR ')}))", attribute_path])
          else
            return self
          end
          advanced_query(query_string, attribute_path, attribute_path_exists)
        end

        def advanced_query(query_string, attribute_path, attribute_path_exists = true, skip_attribute_exists_query = false)
          search_query = DataCycleCore::Search
            .where(Arel.sql(advanced_query_string(query_string, attribute_path, attribute_path_exists, skip_attribute_exists_query)))
            .where(search[:content_data_id].eq(thing[:id]))
          search_query = search_query.where(locale: @locale) if @locale.present?

          reflect(@query.where(search_query.select(1).arel.exists))
        end

        def advanced_query_string(query_string, attribute_path, attribute_path_exists, skip_attribute_exists_query)
          return query_string if skip_attribute_exists_query
          return [attribute_path_exists(attribute_path), query_string].compact_blank.join(' AND ').prepend('(').concat(')') if attribute_path_exists == true

          [attribute_path_not_exists(attribute_path), query_string].compact_blank.join(' OR ').prepend('(').concat(')')
        end

        # One `advanced_attributes @> {"<path>": ["<id>"]}` test per requested id, ORed, which
        # index_searches_on_advanced_attributes (GIN jsonb_ops) can serve as an index condition.
        #
        # It replaces `ARRAY(SELECT jsonb_array_elements_text(advanced_attributes -> '<path>'))
        # ::uuid[] && ARRAY[<ids>]::uuid[]`. That form derives an array per row before comparing,
        # so no index on advanced_attributes can serve it and the filter plans as a Seq Scan over
        # every row of searches. On 612k rows the whole filter went from 427 ms to 0.12 ms.
        #
        # The two agree row for row -- 2.4M row/value comparisons over real data, no disagreement.
        # jsonb `@>` compares arrays by subset, so ORing single element containments is exactly
        # the overlap `&&` expressed. `&&` compared uuids rather than strings though, and `::uuid`
        # normalizes case, so ARRAY['550E8400-...']::uuid[] matched a stored '550e8400-...'. `@>`
        # compares JSON strings, hence the downcase. Lower case is the right target because that
        # is what the stored side holds by construction: Content::UpdateSearch#parse_advanced_data
        # writes Concept#id straight from a Postgres uuid column. Only the requested
        # side needs normalizing, since it arrives verbatim from filter[attributes][...][in][] and
        # ApiService#transform_values_for_query rewrites date and string types only.
        #
        # Where the old form raised instead of answering, this one answers false: on an element
        # that is not a uuid (`invalid input syntax for type uuid: "[]"`) or on a path holding a
        # scalar (`cannot extract elements from a scalar`). That cannot change the result of a
        # query that previously succeeded.
        #
        # Only :equals is rewritten. :not_equals negates the test, which no index can serve, and
        # `NOT(a @> ...)` is NULL rather than true for a row whose advanced_attributes is NULL --
        # so rewriting it would drop rows the old form returns, for nothing in exchange.
        #
        # @return [String] a parenthesized OR, safe to AND into advanced_query_string
        def advanced_classification_contains(attribute_path, value)
          conditions = Array.wrap(value).map do |id|
            sanitize_sql(['searches.advanced_attributes @> ?::jsonb', { attribute_path => [id.to_s.downcase] }.to_json])
          end

          "(#{conditions.join(' OR ')})"
        end

        def attribute_path_exists(path)
          sanitize_sql(['jsonb_path_exists(advanced_attributes, :path)', { path: "$.\"#{path}\"" }])
        end

        def attribute_path_not_exists(path)
          sanitize_sql(['NOT(jsonb_path_exists(advanced_attributes, :path))', { path: "$.\"#{path}\"" }])
        end
      end
    end
  end
end
