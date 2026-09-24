# frozen_string_literal: true

module DataCycleCore
  module ConceptSchemeExtensions
    # Set-based writes of a whole scheme: one statement per import run instead of a model write per
    # concept. Two entry points, by the identity the caller has - an external key pair, or a full
    # path of names.
    module BulkImport
      extend ActiveSupport::Concern

      # @param attributes [Array<Hash>] rows of :external_key, :parent_external_key, :name/:name_i18n
      #   and optionally :description(_i18n), :uri, :order_a, :internal, :assignable,
      #   :external_system_id (defaults to this scheme's)
      def insert_all_external_concepts(attributes)
        import_external_concepts(attributes, add_missing: true)
      end

      def upsert_all_external_concepts(attributes)
        import_external_concepts(attributes, upsert: true)
      end

      # @param concept_attributes [Array<Hash>] rows of :path (the names from this scheme downwards)
      #   and optionally :name_i18n, :external_system_id
      def insert_all_concepts_by_path(concept_attributes)
        sql_values = []

        concept_attributes.each do |row|
          value = transform_row_data(row.deep_dup)

          next if value.nil? || sql_values.any? { |sv| sv[3] == value[3] }

          sql_values.push(value)

          value[4].each.with_index(1) do |a_name, i|
            next if a_name == name

            ancestor = transform_row_data({ path: value[4][0...i] })
            sql_values.push(ancestor) if ancestor.present? && sql_values.none? { |sv| sv[3] == ancestor[3] }
          end
        end

        # an empty list would render `VALUES` without a single tuple -- a syntax error, not a no-op
        return if sql_values.blank?

        sql_values.each do |v|
          v[3].reverse!
          v[4].reverse!
        end

        sql = <<~SQL.squish
          WITH raw_data(concept_scheme_id, name_i18n, name, full_path_names, parent_path_names, external_system_id) AS (
            VALUES #{Array.new(sql_values.size, '(?::uuid, ?::jsonb, ?, ARRAY[?]::varchar[], ARRAY[?]::varchar[], ?::uuid)').join(', ')}
          ),
          concept_data AS (
            SELECT DISTINCT ON (raw_data.full_path_names) raw_data.*,
              COALESCE(concepts.id, uuid_generate_v4()) AS concept_id
            FROM raw_data
              LEFT OUTER JOIN concept_paths ON concept_paths.full_path_names = raw_data.full_path_names
              LEFT OUTER JOIN concepts ON concepts.id = concept_paths.id
            ORDER BY raw_data.full_path_names, concepts.id ASC NULLS LAST
          ),
          new_concepts AS (
            INSERT INTO concepts (id, concept_scheme_id, internal_name, name_i18n, external_system_id, created_at, updated_at)
            SELECT concept_data.concept_id,
              concept_data.concept_scheme_id,
              concept_data.name,
              concept_data.name_i18n,
              concept_data.external_system_id,
              NOW(),
              NOW()
            FROM concept_data ON CONFLICT (id) DO NOTHING
          ),
          concept_links_data AS (
            SELECT parent_data.concept_id AS parent_id, concept_data.concept_id AS child_id
            FROM concept_data
              LEFT OUTER JOIN concept_data parent_data ON parent_data.full_path_names = concept_data.parent_path_names
          )
          INSERT INTO concept_links (parent_id, child_id, link_type)
          SELECT concept_links_data.parent_id, concept_links_data.child_id, '#{DataCycleCore::ConceptLink::LINK_TYPE_BROADER}'
          FROM concept_links_data
          ON CONFLICT (child_id) WHERE link_type = '#{DataCycleCore::ConceptLink::LINK_TYPE_BROADER}' DO NOTHING;
        SQL

        ActiveRecord::Base.connection.exec_query(
          ActiveRecord::Base.send(:sanitize_sql_array, [sql, *sql_values.flatten(1)])
        )
      end

      private

      def import_external_concepts(attributes, upsert: false, add_missing: false)
        raise ArgumentError, 'attributes must be an array' unless attributes.is_a?(Array)
        raise ArgumentError, 'a concept cannot be its own parent (external_key == parent_external_key)' if attributes.any? { |a| a[:external_key] == a[:parent_external_key] }

        query = insert_all_concepts_sql(attributes, upsert:, add_missing:)
        return if query.nil?

        transaction(joinable: false, requires_new: true) do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
          ActiveRecord::Base.connection.exec_query(query)
        end
      end

      def transform_row_data_external(row)
        row = row.with_indifferent_access
        row[:name] = row[:name_i18n].values_at(*I18n.available_locales).compact_blank.first if !row.key?(:name) && row[:name_i18n]&.key?(I18n.locale)
        row[:name_i18n] = { I18n.locale.to_s => row[:name] } if row.key?(:name) && !row.key?(:name_i18n)

        return if row[:name].blank?

        row[:description] = row[:description_i18n].values_at(*I18n.available_locales).compact_blank.first if !row.key?(:description) && row[:description_i18n]&.key?(I18n.locale)
        row[:description_i18n] = { I18n.locale.to_s => row[:description] } if row.key?(:description) && !row.key?(:description_i18n)

        [
          id,
          row[:external_system_id].presence || external_system_id,
          row[:external_key],
          row[:parent_external_key],
          row[:name],
          (row[:name_i18n] || {}).to_json,
          (row[:description_i18n] || {}).to_json,
          row[:uri],
          row[:order_a],
          row.key?(:internal) ? row[:internal] : false,
          row.key?(:assignable) ? row[:assignable] : true
        ]
      end

      def do_concepts_sql(upsert: false, add_missing: false)
        return 'DO NOTHING' unless upsert || add_missing

        name_value = "COALESCE(concepts.name_i18n, '{}'::jsonb) || COALESCE(EXCLUDED.name_i18n, '{}'::jsonb)"
        name_value = "COALESCE(EXCLUDED.name_i18n, '{}'::jsonb) || COALESCE(concepts.name_i18n, '{}'::jsonb)" if add_missing
        description_value = "COALESCE(concepts.description_i18n, '{}'::jsonb) || COALESCE(EXCLUDED.description_i18n, '{}'::jsonb)"
        description_value = "COALESCE(EXCLUDED.description_i18n, '{}'::jsonb) || COALESCE(concepts.description_i18n, '{}'::jsonb)" if add_missing
        uri_value = 'EXCLUDED.uri'
        uri_value = "COALESCE(NULLIF(concepts.uri, ''), #{uri_value})" if add_missing

        set_clauses = [
          "name_i18n = #{name_value}",
          "description_i18n = #{description_value}",
          "uri = #{uri_value}"
        ]
        # Compare the *resulting* value against the current one (not against the incoming,
        # possibly single-locale, EXCLUDED value) so a no-op merge does not rewrite the row
        # and bump updated_at on every re-import.
        where_clauses = [
          "concepts.name_i18n IS DISTINCT FROM (#{name_value})",
          "concepts.description_i18n IS DISTINCT FROM (#{description_value})",
          "concepts.uri IS DISTINCT FROM (#{uri_value})"
        ]

        unless add_missing
          order_value = 'COALESCE(EXCLUDED.order_a, concepts.order_a)'
          set_clauses << "order_a = #{order_value}"
          where_clauses << "concepts.order_a IS DISTINCT FROM (#{order_value})"
        end

        if upsert
          set_clauses << 'concept_scheme_id = EXCLUDED.concept_scheme_id'
          where_clauses << 'concepts.concept_scheme_id IS DISTINCT FROM EXCLUDED.concept_scheme_id'

          if I18n.locale == I18n.default_locale
            set_clauses << 'internal_name = EXCLUDED.internal_name'
            where_clauses << 'concepts.internal_name IS DISTINCT FROM EXCLUDED.internal_name'
          end
        end

        set_clauses << 'updated_at = NOW()'

        <<~SQL.squish
          DO UPDATE SET #{set_clauses.join(', ')}
          WHERE #{where_clauses.join(' OR ')}
        SQL
      end

      def do_concept_links_sql(upsert: false)
        return 'DO NOTHING' unless upsert

        <<~SQL.squish
          DO UPDATE SET parent_id = EXCLUDED.parent_id
          WHERE concept_links.parent_id IS DISTINCT FROM EXCLUDED.parent_id
        SQL
      end

      def insert_all_concepts_sql(attributes, upsert: false, add_missing: false)
        filtered_attributes = attributes.compact_blank
          .filter { |row| row[:external_key].present? && (row[:name].present? || row[:name_i18n].present?) }
        sql_values = filtered_attributes.filter_map { |row| transform_row_data_external(row) }
        return if sql_values.blank?

        sets_internal = filtered_attributes.any? { |row| row.key?(:internal) }
        sets_assignable = filtered_attributes.any? { |row| row.key?(:assignable) }

        <<~SQL.squish
          WITH raw_data(concept_scheme_id, external_system_id, external_key, parent_external_key, internal_name, name_i18n, description_i18n, uri, order_a, internal, assignable) AS (
            VALUES #{Array.new(sql_values.size, '(?::uuid, ?::uuid, ?::varchar, ?::varchar, ?::varchar, ?::jsonb, ?::jsonb, ?::varchar, ?::integer, ?::boolean, ?::boolean)').join(', ')}
          ), data AS (
            SELECT DISTINCT * FROM raw_data
          ), inserted_concepts AS (
            INSERT INTO concepts (concept_scheme_id, external_system_id, external_key, internal_name, name_i18n, description_i18n, uri, order_a, created_at, updated_at#{', internal' if sets_internal}#{', assignable' if sets_assignable})
            (SELECT concept_scheme_id, external_system_id, external_key, internal_name, name_i18n, description_i18n, uri, order_a, NOW(), NOW()#{', internal' if sets_internal}#{', assignable' if sets_assignable} FROM data)
            ON CONFLICT (external_system_id, external_key) WHERE external_key IS NOT NULL
              #{do_concepts_sql(upsert:, add_missing:)}
            RETURNING *
          ), parent_concepts AS (
            SELECT concepts.id, concepts.external_system_id, concepts.external_key
            FROM data
            JOIN concepts
              ON data.external_system_id IS NOT DISTINCT FROM concepts.external_system_id AND
                data.parent_external_key IS NOT DISTINCT FROM concepts.external_key
            UNION
            SELECT inserted_concepts.id, inserted_concepts.external_system_id, inserted_concepts.external_key
            FROM data
            JOIN inserted_concepts
              ON data.external_system_id IS NOT DISTINCT FROM inserted_concepts.external_system_id AND
                data.parent_external_key IS NOT DISTINCT FROM inserted_concepts.external_key
          ), all_concepts AS (
            SELECT concepts.id, concepts.external_system_id, concepts.external_key
            FROM data
            JOIN concepts
              ON data.external_system_id IS NOT DISTINCT FROM concepts.external_system_id AND
                data.external_key IS NOT DISTINCT FROM concepts.external_key
            UNION
            SELECT inserted_concepts.id, inserted_concepts.external_system_id, inserted_concepts.external_key
            FROM inserted_concepts
          ), concept_links_data AS (
            SELECT parent_concepts.id parent_id, all_concepts.id child_id
            FROM all_concepts
            JOIN data ON data.external_system_id IS NOT DISTINCT FROM all_concepts.external_system_id AND data.external_key IS NOT DISTINCT FROM all_concepts.external_key
            LEFT OUTER JOIN parent_concepts ON data.external_system_id IS NOT DISTINCT FROM parent_concepts.external_system_id AND
              data.parent_external_key = parent_concepts.external_key
          ), inserted_concept_links AS (
            INSERT INTO concept_links (parent_id, child_id, link_type)
            (SELECT concept_links_data.parent_id, concept_links_data.child_id, '#{DataCycleCore::ConceptLink::LINK_TYPE_BROADER}' FROM concept_links_data)
            ON CONFLICT (child_id) WHERE link_type = '#{DataCycleCore::ConceptLink::LINK_TYPE_BROADER}'
              #{do_concept_links_sql(upsert:)}
          )
          SELECT * FROM concept_links_data;
        SQL
          .then { |sql| ActiveRecord::Base.send(:sanitize_sql_array, [sql, *sql_values.flatten(1)]) }
      end

      def transform_row_data(row)
        return if row[:path].blank?
        raise 'concept path cannot contain blank values' if row[:path].include?(nil)

        row[:path].unshift(name) if row[:path].first != name
        row[:name] = row[:path].last unless row.key?(:name)
        row[:name] = row.dig(:name_i18n, I18n.locale.to_s) if !row.key?(:name) && row[:name_i18n]&.key?(I18n.locale.to_s)
        row[:name_i18n] = { I18n.locale.to_s => row[:name] } if row.key?(:name) && !row.key?(:name_i18n)

        [
          id,
          row[:name_i18n]&.to_json,
          row[:name],
          row[:path],
          row[:path][...-1],
          row[:external_system_id]
        ]
      end
    end
  end
end
