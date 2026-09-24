# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sortable
      include Proximity

      def reset_sort
        reflect(query_without_order)
      end

      def sort_default(_ordering = 'DESC')
        reflect(
          query_without_order.order(
            thing[:boost].desc,
            thing[:updated_at].desc,
            thing[:id].desc
          )
        )
      end

      def sort_collection_manual_order(ordering, watch_list_id)
        return self if watch_list_id.nil?

        reflect(
          query_without_order
            .joins(
              sanitize_sql([
                             'LEFT OUTER JOIN watch_list_data_hashes ON watch_list_data_hashes.watch_list_id = ? AND watch_list_data_hashes.thing_id = things.id',
                             watch_list_id
                           ])
            )
            .order(
              watch_list_data_hash[:order_a].send(sanitized_ordering(ordering.presence || 'asc')),
              watch_list_data_hash[:created_at].asc,
              thing[:id].desc
            )
        )
      end

      # setseed does not work, if postgres spawns parallel workers for subqueries, so we use md5 hashing for random sorting with seed to ensure consistent results.
      def sort_random(_ordering = nil, seed = nil)
        order_string = if seed.present?
                         sanitize_sql_for_order([Arel.sql('md5(things.id || ?::TEXT)'), seed.to_s])
                       else
                         sanitize_sql_for_order('random()')
                       end

        reflect(query_without_order.order(order_string))
      end

      def sort_boost(ordering)
        reflect(
          query_without_order
            .order(
              thing[:boost].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end

      def sort_updated_at(ordering)
        reflect(
          query_without_order
            .order(
              thing[:updated_at].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end
      alias sort_dct_modified sort_updated_at

      def sort_cache_valid_since(ordering)
        reflect(
          query_without_order
            .order(
              thing[:cache_valid_since].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end
      alias sort_dc_touched sort_cache_valid_since

      def sort_created_at(ordering)
        reflect(
          query_without_order
            .order(
              thing[:created_at].send(sanitized_ordering(ordering)),
              thing[:id].desc
            )
        )
      end
      alias sort_dct_created sort_created_at

      def sort_translated_name(ordering)
        reflect(
          query_without_order
            .joins(locale_join('thing_translations', 'thing_id', 'content'))
            .order(
              sanitized_order_string("thing_translations.content ->> 'name'", ordering, true),
              thing[:id].desc
            )
        )
      end
      alias sort_name sort_translated_name

      def sort_advanced_attribute(ordering, attribute_path)
        reflect(
          query_without_order
            .joins(locale_join('searches', 'content_data_id', 'advanced_attributes'))
            .order(
              sanitized_order_string("searches.advanced_attributes -> '#{attribute_path}'", ordering, true),
              thing[:id].desc
            )
        )
      end

      # Sorts by a numeric advanced_search attribute. The values sit in searches.advanced_attributes
      # as a JSON ARRAY (walk_advanced collects the occurrences from embedded contents too), which is
      # why sort_advanced_attribute -- which orders by the array itself -- is no good here: jsonb
      # compares arrays by LENGTH first, so [1,2] would come before [9].
      # Hence a reduction to a scalar per direction: DESC by the largest, ASC by the smallest
      # element, so that "the longest" and "the shortest" both have the extreme value at the front.
      def sort_advanced_attribute_numeric(ordering, attribute_path)
        return self if attribute_path.blank?

        # sanitized_ordering raises on anything but asc/desc, which covers the interpolation.
        aggregate = sanitized_ordering(ordering) == 'desc' ? 'MAX' : 'MIN'
        order_string = sanitize_sql([
                                      "(SELECT #{aggregate}((e)::decimal) FROM jsonb_array_elements(searches.advanced_attributes -> ?) e WHERE jsonb_typeof(e) = 'number')",
                                      attribute_path
                                    ])

        reflect(
          query_without_order
            .joins(locale_join('searches', 'content_data_id', 'advanced_attributes'))
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing[:id].desc
            )
        )
      end

      def sort_legacy_fulltext_search(ordering, value)
        return self if value.blank?

        locale = @locale&.first || I18n.default_locale.to_s
        normalized_value = DataCycleCore::MasterData::DataConverter.string_to_string(value)
        return self if normalized_value.blank?

        search_string = normalized_value.split.join('%')
        order_sql = <<~SQL.squish
          things.boost * (
            8 * similarity(searches.concept_string, :search_string) +
            4 * similarity(searches.headline, :search_string) +
            2 * ts_rank_cd(searches.words, plainto_tsquery(pg_dict_mappings.dict, :search),16) +
            1 * similarity(searches.full_text, :search_string)
          )
        SQL

        order_string = sanitize_sql([order_sql, { search_string: "%#{search_string}%", search: normalized_value }])

        reflect(
          query_without_order
            .joins(sanitize_sql(['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ? LEFT OUTER JOIN pg_dict_mappings ON pg_dict_mappings.locale = searches.locale', locale]))
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      def sort_ts_rank_fulltext_search(ordering, value)
        value, fields = value.values_at(:value, :fields) if value.is_a?(Hash)
        return self if value.blank?

        q = text_to_websearch_tsquery(value)
        weights = fulltext_fields_to_weights(fields)
        locale = @locale&.first || I18n.default_locale.to_s
        order_string = Feature::TsQueryFulltextSearch.sorting_string

        reflect(
          query_without_order
            .joins(sanitize_sql(['LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = ?', locale]))
            .order(
              sanitized_order_string(sanitize_sql([order_string, { q:, weights:, locale: }]), ordering, true),
              thing[:id].desc
            )
        )
      end

      def sort_type(ordering, value)
        return self if value.blank?

        order_string = sanitize_sql(["array_position(ARRAY[?]::varchar[], CONCAT('dcls:', things.template_name))", value])
        # second variant to match parent types via array intersection, but performance is worse than the first one, so currently not used
        # order_string = sanitize_sql(['array_position(ARRAY[:value]::varchar[], (array_intersect(ARRAY [:value]::varchar [], thing_templates.api_schema_types))[1])', value])

        reflect(
          query_without_order
            # .joins(:thing_template)
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      # #50554: order things by a prioritized list of content UUIDs; content not in the list sorts
      # last (NULLS LAST). Without a list this is a plain sort on things.id.
      def sort_id(ordering, value = nil)
        ids = sanitized_uuid_list(value, '@id')

        return reflect(query_without_order.order(thing[:id].send(sanitized_ordering(ordering)))) if ids.blank?

        order_string = sanitize_sql(['array_position(ARRAY[?]::uuid[], things.id)', ids])

        reflect(
          query_without_order
            .order(
              sanitized_order_string(order_string, ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      # #50091: order things by a prioritized list of concept UUIDs.
      # Content tagged with the first listed UUID (or any of its descendants) comes first, etc.;
      # content matching none of them sorts last (NULLS LAST).
      def sort_dc_classification(ordering, value)
        ids = sanitized_uuid_list(value, 'dc:classification')

        # #50091: at least one UUID must be given -> reject empty (do NOT silently fall back like sort_type)
        invalid_sort_argument!('dc:classification requires at least one classification UUID', value) if ids.blank?

        # Aggregate the priority ONCE in a non-correlated derived table (index scan on
        # concept_id -> GROUP BY thing_id) and hash-join 1:1 to things, instead of a
        # per-row correlated subquery. array_position is 1-based; MIN picks the earliest-listed
        # matching UUID. hidden = false mirrors CollectedConceptContent.without_hidden (#47172);
        # no link_type filter keeps it subtree-inclusive like the default classification filter.
        join_query = sanitize_sql([<<~SQL.squish, ids, ids])
          LEFT OUTER JOIN (
            SELECT thing_id, MIN(array_position(ARRAY[?]::uuid[], concept_id)) AS sort_position
            FROM collected_concept_contents
            WHERE hidden = false
              AND concept_id = ANY(ARRAY[?]::uuid[])
            GROUP BY thing_id
          ) dc_classification_sort ON dc_classification_sort.thing_id = things.id
        SQL

        reflect(
          query_without_order
            .joins(join_query)
            .order(
              sanitized_order_string('dc_classification_sort.sort_position', ordering, true),
              thing[:updated_at].desc,
              thing[:id].desc
            )
        )
      end

      # The direction is not client input the way a sort argument is: the API derives it from the
      # +/- sign of the sort key and the backend UI validates it against ASC/DESC, so anything else
      # is a bug and stays an InvalidArgumentError instead of invalid_sort_argument!'s 400 detail.
      def sanitized_ordering(ordering)
        ordering = ordering&.downcase

        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for ordering: #{ordering}" unless ['asc', 'desc'].include?(ordering)

        ordering
      end

      def sanitized_order_string(order_string, order, nulls_last = false)
        ordering = sanitized_ordering(order)
        raise DataCycleCore::Error::Api::InvalidArgumentError, "Invalid value for order string: #{order_string}" if order_string.blank?

        order_nulls = nulls_last ? ' NULLS LAST' : ''
        Arel.sql(sanitize_sql_for_order("#{order_string} #{ordering}#{order_nulls}"))
      end

      # used to alias the fulltext search method based on feature flag without class reloading
      def self.alias_fulltext_search_method!
        if Feature::TsQueryFulltextSearch.enabled?
          alias_method :sort_fulltext_search, :sort_ts_rank_fulltext_search
        else
          alias_method :sort_fulltext_search, :sort_legacy_fulltext_search
        end
      end

      alias_fulltext_search_method!
      alias sort_similarity sort_fulltext_search

      private

      # SECURITY (#50091, #50554): the anchored uuid? check is the injection boundary for sort values
      # that end up inside a raw ARRAY[...] literal. Callers decide what a blank list means.
      def sanitized_uuid_list(value, sort_key)
        ids = Array.wrap(value).flat_map { |v| v.to_s.split(',') }.filter_map { |v| v.strip.presence }
        invalid_ids = ids.reject(&:uuid?)

        invalid_sort_argument!("#{sort_key} requires valid UUIDs", invalid_ids) if invalid_ids.present?

        ids
      end

      # Reject a sort argument the way ApiService reports every other unusable query parameter: with
      # source.parameter 'sort' and a +detail+ (ErrorHandler#bad_request_api_error), where
      # Error::Api::InvalidArgumentError would render its i18n title, "Invalid Query Parameter", alone.
      #
      # The sort parameter can carry several keys, so +detail+ names the one at fault - it is the half
      # the client reads. The rejected value goes into the raise message and stays internal, because
      # ActionController logs a handled exception's message but never BadRequestError#data.
      def invalid_sort_argument!(detail, value)
        raise DataCycleCore::Error::Api::BadRequestError.new({
          parameter_path: 'sort',
          type: 'invalid_parameter',
          detail:
        }), "sort: #{detail}, got: #{value.inspect}"
      end

      # Join onto a translated table (thing_translations, searches) as the sort source.
      #
      # With a requested language: exactly that language's row, as before.
      #
      # WITHOUT a requested language (`locale: nil`, which `language: ['all']` produces -- how MCP
      # queries, so that counts cover every translation) it must NOT be pinned silently to the
      # default locale: contents without a row in that one language would get a NULL sort key and
      # could never appear in a desc top-N although they count towards `count` and an unsorted
      # search returns them (measured in vcloud-dev: 114,698 things have an en but no de searches
      # row). Instead a LATERAL that yields EXACTLY ONE row per thing -- the default locale
      # preferred, otherwise the alphabetically first one present. A LATERAL rather than a join
      # without a locale condition, because the latter would produce one result row per translation
      # and thereby multiply contents.
      #
      # The alias stays the table name, so the callers' ORDER BY expressions are unchanged.
      def locale_join(table, thing_key, column)
        return sanitize_sql(["LEFT OUTER JOIN #{table} ON #{table}.#{thing_key} = things.id AND #{table}.locale = ?", @locale.first]) if @locale&.first.present?

        sanitize_sql([<<~SQL.squish, I18n.default_locale.to_s])
          LEFT OUTER JOIN LATERAL (
            SELECT t.#{column}
            FROM #{table} t
            WHERE t.#{thing_key} = things.id
            ORDER BY (t.locale = ?) DESC, t.locale
            LIMIT 1
          ) #{table} ON TRUE
        SQL
      end

      def query_without_order
        @query.reorder(nil).except(:joins)
      end
    end
  end
end
