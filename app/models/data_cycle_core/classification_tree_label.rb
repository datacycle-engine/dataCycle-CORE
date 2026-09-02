# frozen_string_literal: true

require 'csv'

module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord
    CCC_REFRESH_BATCH_SIZE = 1_000

    validates :name, presence: true

    after_update :add_things_cache_invalidation_job_update, if: :trigger_things_cache_invalidation?
    after_update :add_things_webhooks_job_update, if: :trigger_things_webhooks?
    # Redmine #50677: hidden_mappings changes which concepts of this tree the mapped contents
    # effectively carry, so collected_classification_contents, the search index and the webhooks of
    # every affected content have to be handled. Always async: a flagged tree can hold thousands of
    # mappings.
    #
    # This callback is the *only* thing that materialises the flag. `concept_schemes.hidden_mappings`
    # itself is kept in sync by the trigger functions, so the flag is never wrong — but a write that
    # skips the model (upsert_all in the concept importer, an update_all, a manual UPDATE) leaves the
    # already-materialised collected_classification_contents.hidden rows behind, and a hidden concept
    # gives no visible sign of being stale. Deliberately not a DB trigger: the refresh rewrites CCC for
    # every content reaching the tree (six figures on a large tree), which is exactly the work this job
    # exists to keep out of the writing transaction. After such a write, queue it by hand:
    #   DataCycleCore::CacheInvalidationJob.perform_later('DataCycleCore::ClassificationTreeLabel', id, 'refresh_hidden_mappings')
    after_update :add_hidden_mappings_job_update, if: :saved_change_to_hidden_mappings?
    after_destroy :clean_stored_filters

    acts_as_paranoid

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'

    has_many :classification_trees, dependent: :destroy
    has_many :classification_aliases, through: :classification_trees, source: :sub_classification_alias do
      def roots
        joins(:classification_tree).where(classification_trees: { parent_classification_alias_id: nil })
      end
    end

    has_one :concept_scheme, foreign_key: :id, dependent: :delete, inverse_of: :classification_tree_label
    has_many :concepts, through: :concept_scheme

    has_many :classification_aliases_with_deleted, -> { with_deleted }, through: :classification_trees, source: :sub_classification_alias

    has_many :classifications, through: :classification_aliases
    has_many :things, -> { unscope(:order).distinct }, through: :concepts

    scope :visible, ->(context) { where('? = ANY("classification_tree_labels"."visibility")', context) }
    scope :search, ->(q) { where('classification_tree_labels.name ILIKE :q', { q: "%#{q.squish.gsub(/\s/, '%')}%" }) }
    scope :order_by_similarity, ->(term) { order([Arel.sql('similarity(classification_tree_labels.name, ?) DESC'), term]) }

    # whether a change to this tree or any of its concepts is allowed to webhook the affected contents
    # at all — the switch every webhook fan-out here and in ClassificationAlias is gated on
    def trigger_webhooks?
      change_behaviour.to_a.include?('trigger_webhooks')
    end

    def create_classification_alias(*classification_attributes)
      parent_classification_alias = nil
      classification_attributes.map { |attributes|
        if attributes.is_a?(String)
          {
            name: attributes
          }
        else
          attributes
        end
      }.each do |attributes|
        classification_alias = if parent_classification_alias
                                 parent_classification_alias
                                   .sub_classification_alias
                                   .find_or_initialize_by(name: attributes[:name], external_source: attributes[:external_source], uri: attributes[:uri], external_key: attributes[:external_key])
                               else
                                 classification_aliases.roots
                                   .find_or_initialize_by(name: attributes[:name], external_source: attributes[:external_source], uri: attributes[:uri], external_key: attributes[:external_key])
                               end

        if classification_alias.new_record?
          classification_alias.internal = attributes[:internal] || false
          classification_alias.save!

          classification = Classification.create!(name: attributes[:name],
                                                  external_source: attributes[:external_source],
                                                  external_key: attributes[:external_key],
                                                  uri: attributes[:uri])

          ClassificationGroup.create!(classification:,
                                      classification_alias:)

          ClassificationTree.create!(classification_tree_label: self,
                                     parent_classification_alias:,
                                     sub_classification_alias: classification_alias)
        end

        parent_classification_alias = classification_alias
      end

      parent_classification_alias
    end

    def create_or_update_classification_alias_by_name(*classification_attributes)
      parent_classification_alias = nil
      classification_attributes.map { |attributes|
        if attributes.is_a?(String)
          {
            name: attributes
          }
        else
          attributes.compact_blank!
        end
      }.each do |attributes|
        classification_alias = if parent_classification_alias
                                 parent_classification_alias
                                   .sub_classification_alias
                                   .find_or_initialize_by(name: attributes[:name])
                               else
                                 classification_aliases.roots
                                   .find_or_initialize_by(name: attributes[:name])
                               end

        if classification_alias.new_record?
          classification_alias.save!

          classification = Classification.create!(attributes.slice(:name, :external_source_id, :external_key, :uri))

          ClassificationGroup.create!(classification:,
                                      classification_alias:)

          ClassificationTree.create!(classification_tree_label: self,
                                     parent_classification_alias:,
                                     sub_classification_alias: classification_alias)
        else
          classification_alias.primary_classification.update!(attributes.slice(:external_source_id, :external_key, :uri))
        end
        classification_alias.update!(attributes.slice(:external_source_id, :uri))
        parent_classification_alias = classification_alias
      end

      parent_classification_alias
    end

    def insert_all_external_classifications(attributes)
      raise ArgumentError, 'attributes must be an array' unless attributes.is_a?(Array)
      raise ArgumentError, 'a concept cannot be its own parent (external_key == parent_external_key)' if attributes.any? { |a| a[:external_key] == a[:parent_external_key] }

      query = insert_all_classifications_sql(attributes, add_missing: true)

      transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
        ActiveRecord::Base.connection.exec_query(query)
      end
    end

    def upsert_all_external_classifications(attributes)
      raise ArgumentError, 'attributes must be an array' unless attributes.is_a?(Array)
      raise ArgumentError, 'a concept cannot be its own parent (external_key == parent_external_key)' if attributes.any? { |a| a[:external_key] == a[:parent_external_key] }

      query = insert_all_classifications_sql(attributes, upsert: true)

      transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
        ActiveRecord::Base.connection.exec_query(query)
      end
    end

    def insert_all_classifications_by_path(classification_attributes)
      sql_values = []

      classification_attributes.each do |row|
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
        WITH raw_data(classification_tree_label_id, name_i18n, name, full_path_names, parent_path_names, external_source_id) AS (
          VALUES #{Array.new(sql_values.size, '(?::uuid, ?::jsonb, ?, ARRAY[?]::varchar[], ARRAY[?]::varchar[], ?::uuid)').join(', ')}
        ),
        classification_data AS (
          SELECT DISTINCT ON (raw_data.full_path_names) raw_data.*,
            coalesce(ca.id, uuid_generate_v4()) AS classification_alias_id,
            coalesce(pcg.classification_id, uuid_generate_v4()) AS classification_id
          FROM raw_data
            LEFT OUTER JOIN classification_alias_paths cap ON cap.full_path_names = raw_data.full_path_names
            LEFT OUTER JOIN classification_aliases ca ON ca.id = cap.id
            AND ca.deleted_at IS NULL
            LEFT OUTER JOIN primary_classification_groups pcg ON pcg.classification_alias_id = cap.id
            AND pcg.deleted_at IS NULL
            ORDER BY raw_data.full_path_names, ca.id ASC NULLS LAST
        ),
        classifications AS (
          INSERT INTO classifications (id, name, external_source_id, created_at, updated_at)
          SELECT classification_data.classification_id,
            classification_data.name,
            classification_data.external_source_id,
            NOW(),
            NOW()
          FROM classification_data ON conflict (id) DO NOTHING
        ),
        new_classification_aliases AS (
          INSERT INTO classification_aliases (
              id,
              internal_name,
              name_i18n,
              external_source_id,
              created_at,
              updated_at
            )
          SELECT classification_data.classification_alias_id,
            classification_data.name,
            classification_data.name_i18n,
            classification_data.external_source_id,
            NOW(),
            NOW()
          FROM classification_data ON conflict (id) DO NOTHING RETURNING *
        ),
        classification_groups AS (
          INSERT INTO classification_groups (classification_id, classification_alias_id) (
              SELECT classification_data.classification_id,
                classification_data.classification_alias_id
              FROM classification_data
            ) ON conflict(classification_id, classification_alias_id)
          WHERE deleted_at IS NULL DO NOTHING
        ),
        classification_trees_data AS (
          SELECT classification_data.classification_tree_label_id AS classification_tree_label_id,
            joined_cd.classification_alias_id AS parent_id,
            classification_data.classification_alias_id AS child_id,
            classification_data.external_source_id AS external_source_id
          FROM classification_data
            LEFT OUTER JOIN classification_data joined_cd ON joined_cd.full_path_names = classification_data.parent_path_names
        )
        INSERT INTO classification_trees(
          classification_tree_label_id,
          parent_classification_alias_id,
          classification_alias_id,
          external_source_id,
          created_at,
          updated_at
        )
        SELECT ctd.classification_tree_label_id,
          ctd.parent_id,
          ctd.child_id,
          ctd.external_source_id,
          NOW(),
          NOW()
        FROM classification_trees_data ctd
        LEFT OUTER JOIN new_classification_aliases nca on nca.id = ctd.child_id
        ON conflict (classification_alias_id)
        WHERE deleted_at IS NULL DO NOTHING;
      SQL

      ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, *sql_values.flatten(1)])
      )
    end

    def to_csv(include_contents: false)
      CSV.generate do |csv|
        csv << [name]
        classification_aliases.includes(:classification_alias_path, :classifications).sort_by(&:full_path).each do |classification_alias|
          csv << (Array.new(classification_alias.ancestors.count) + [classification_alias.name])

          next unless include_contents

          classification_alias.classifications.includes(things: :translations).map(&:things).flatten.each do |content|
            content&.translations&.each do |content_translation|
              row = Array.new(classification_alias.ancestors.count + 1)
              row += [
                content.template_name,
                content_translation.locale,
                content_translation.content&.dig('name')
              ]
              csv << row
            end
          end
        end
      end
    end

    def to_csv_for_mappings
      CSV.generate do |csv|
        csv << ['Pfad zur Klassifizierung', 'Pfad zu gemappter Klassifizierung']
        classification_aliases.includes(:classification_alias_path).map(&:full_path).sort.each do |fp|
          csv << [fp, nil]
        end
      end
    end

    def to_csv_with_mappings
      CSV.generate do |csv|
        csv << ['Pfad zur Klassifizierung', 'Pfad zu gemappter Klassifizierung']
        classification_aliases.includes(:classification_alias_path, additional_classifications: [{ primary_classification_alias: :classification_alias_path }]).reorder(nil).order('array_reverse(classification_alias_paths.full_path_names) ASC').references(:classification_alias_path).find_each do |ca|
          ca.additional_classifications.map(&:primary_classification_alias).each do |mapped_ca|
            csv << [ca.full_path, mapped_ca.full_path]
          end
        end
      end
    end

    def to_csv_with_inverse_mappings
      CSV.generate do |csv|
        csv << ['Pfad zur Klassifizierung', 'Pfad zu gemappter Klassifizierung']
        classification_aliases.includes(:classification_alias_path, primary_classification: [{ additional_classification_aliases: :classification_alias_path }]).reorder(nil).order('array_reverse(classification_alias_paths.full_path_names) ASC').references(:classification_alias_path).find_each do |ca|
          ca.primary_classification.additional_classification_aliases.each do |mapped_ca|
            csv << [mapped_ca.full_path, ca.full_path]
          end
        end
      end
    end

    def ancestors
      []
    end

    def visible?(context)
      visibility&.include?(context)
    end

    def first_available_locale(_locale)
      :de
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:ConceptScheme'
      }
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_source&.identifier })
        .merge(attributes)
    end

    def sort_classifications_alphabetically!
      raw_sql = <<~SQL.squish
        UPDATE classification_aliases
        SET order_a = w.order_a
        FROM (
            WITH RECURSIVE paths (id, full_internal_name, tree_label_id) AS (
              SELECT classification_aliases.id,
                ARRAY [classification_aliases.internal_name],
                classification_trees.classification_tree_label_id
              FROM classification_trees
                JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
                AND classification_aliases.deleted_at IS NULL
              WHERE classification_trees.parent_classification_alias_id IS NULL
                AND classification_trees.deleted_at IS NULL
                AND classification_trees.classification_tree_label_id = :id
              UNION
              SELECT classification_trees.classification_alias_id,
                paths.full_internal_name || classification_aliases.internal_name,
                classification_trees.classification_tree_label_id
              FROM classification_trees
                JOIN paths ON paths.id = classification_trees.parent_classification_alias_id
                JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
                AND classification_aliases.deleted_at IS NULL
              WHERE classification_trees.deleted_at IS NULL
                AND classification_trees.classification_tree_label_id = :id
            )
            SELECT paths.id,
              (
                ROW_NUMBER() OVER (
                  PARTITION BY classification_tree_labels.id
                  ORDER BY paths.full_internal_name ASC
                )
              ) AS order_a
            FROM paths
              JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
          ) w
        WHERE w.id = classification_aliases.id;
      SQL

      ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            raw_sql,
            { id: }
          ]
        )
      )
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id:,
        name: ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon classification_tree_label-icon'),
          name
        ].compact, ' '),
        html_class: model_name.param_key,
        dc_tooltip: "#{model_name.human(count: 1, locale:)}: #{name}",
        class_key: model_name.param_key
      )
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first)
      all.map { |v| v.to_select_option(locale) }
    end

    def stored_filters
      DataCycleCore::StoredFilter.where('parameters::TEXT ILIKE ?', "%#{id}%")
    end

    private

    def transform_row_data_external(row)
      row = row.with_indifferent_access
      row[:name] = row[:name_i18n].values_at(*I18n.available_locales).compact_blank.first if !row.key?(:name) && row[:name_i18n]&.key?(I18n.locale)
      row[:name_i18n] = { I18n.locale.to_s => row[:name] } if row.key?(:name) && !row.key?(:name_i18n)

      return if row[:name].blank?

      row[:description] = row[:description_i18n].values_at(*I18n.available_locales).compact_blank.first if !row.key?(:description) && row[:description_i18n]&.key?(I18n.locale)
      row[:description_i18n] = { I18n.locale.to_s => row[:description] } if row.key?(:description) && !row.key?(:description_i18n)

      [
        id,
        row[:external_source_id].presence || external_source_id,
        row[:external_key],
        row[:parent_external_key],
        row[:name],
        (row[:name_i18n] || {}).to_json,
        row[:description],
        (row[:description_i18n] || {}).to_json,
        row[:uri],
        row[:order_a],
        row.key?(:internal) ? row[:internal] : false,
        row.key?(:assignable) ? row[:assignable] : true
      ]
    end

    def do_update_classifications_sql(upsert: false, add_missing: false)
      do_classifications = 'DO NOTHING'

      if I18n.locale == I18n.default_locale && (upsert || add_missing)
        name_value = 'EXCLUDED.name'
        name_value = "COALESCE(NULLIF(classifications.name, ''), #{name_value})" if add_missing
        description_value = 'EXCLUDED.description'
        description_value = "COALESCE(NULLIF(classifications.description, ''), #{description_value})" if add_missing
        uri_value = 'EXCLUDED.uri'
        uri_value = "COALESCE(NULLIF(classifications.uri, ''), #{uri_value})" if add_missing

        do_classifications = <<~SQL.squish
          DO UPDATE SET name = #{name_value},
            description = #{description_value},
            uri = #{uri_value},
            updated_at = NOW()
          WHERE classifications.name IS DISTINCT FROM EXCLUDED.name
            OR classifications.description IS DISTINCT FROM EXCLUDED.description
            OR classifications.uri IS DISTINCT FROM EXCLUDED.uri
        SQL
      end

      do_classifications
    end

    def do_classification_aliases_sql(upsert: false, add_missing: false)
      return 'DO NOTHING' unless upsert || add_missing

      name_value = "COALESCE(classification_aliases.name_i18n, '{}'::jsonb) || coalesce(EXCLUDED.name_i18n, '{}'::jsonb)"
      name_value = "coalesce(EXCLUDED.name_i18n, '{}'::jsonb) || COALESCE(classification_aliases.name_i18n, '{}'::jsonb)" if add_missing
      description_value = "COALESCE(classification_aliases.description_i18n, '{}'::jsonb) || coalesce(EXCLUDED.description_i18n, '{}'::jsonb)"
      description_value = "coalesce(EXCLUDED.description_i18n, '{}'::jsonb) || COALESCE(classification_aliases.description_i18n, '{}'::jsonb)" if add_missing
      uri_value = 'EXCLUDED.uri'
      uri_value = "COALESCE(NULLIF(classification_aliases.uri, ''), #{uri_value})" if add_missing

      set_clauses = [
        "name_i18n = #{name_value}",
        "description_i18n = #{description_value}",
        "uri = #{uri_value}"
      ]
      # Compare the *resulting* value against the current one (not against the incoming,
      # possibly single-locale, EXCLUDED value) so a no-op merge does not rewrite the row
      # and bump updated_at on every re-import.
      where_clauses = [
        "classification_aliases.name_i18n IS DISTINCT FROM (#{name_value})",
        "classification_aliases.description_i18n IS DISTINCT FROM (#{description_value})",
        "classification_aliases.uri IS DISTINCT FROM (#{uri_value})"
      ]

      unless add_missing
        order_value = 'COALESCE(EXCLUDED.order_a, classification_aliases.order_a)'
        set_clauses << "order_a = #{order_value}"
        where_clauses << "classification_aliases.order_a IS DISTINCT FROM (#{order_value})"
      end

      if I18n.locale == I18n.default_locale && upsert
        set_clauses << 'internal_name = EXCLUDED.internal_name'
        where_clauses << 'classification_aliases.internal_name IS DISTINCT FROM EXCLUDED.internal_name'
      end

      set_clauses << 'updated_at = NOW()'

      <<~SQL.squish
        DO UPDATE SET #{set_clauses.join(', ')}
        WHERE #{where_clauses.join(' OR ')}
      SQL
    end

    def do_classification_trees_sql(upsert: false)
      return 'DO NOTHING' unless upsert

      <<~SQL.squish
        DO UPDATE SET parent_classification_alias_id = EXCLUDED.parent_classification_alias_id,
          classification_tree_label_id = EXCLUDED.classification_tree_label_id,
          external_source_id = EXCLUDED.external_source_id,
          updated_at = NOW()
        WHERE classification_trees.parent_classification_alias_id IS DISTINCT FROM EXCLUDED.parent_classification_alias_id
          OR classification_trees.classification_tree_label_id IS DISTINCT FROM EXCLUDED.classification_tree_label_id
          OR classification_trees.external_source_id IS DISTINCT FROM EXCLUDED.external_source_id
      SQL
    end

    def insert_all_classifications_sql(attributes, upsert: false, add_missing: false)
      filtered_attributes = attributes.compact_blank
        .filter { |row| row[:external_key].present? && (row[:name].present? || row[:name_i18n].present?) }
      sql_values = filtered_attributes.map { |row| transform_row_data_external(row) }
      sets_internal = filtered_attributes.any? { |row| row.key?(:internal) }
      sets_assignable = filtered_attributes.any? { |row| row.key?(:assignable) }

      do_classifications = do_update_classifications_sql(upsert:, add_missing:)
      do_classification_aliases = do_classification_aliases_sql(upsert:, add_missing:)
      do_classification_trees = do_classification_trees_sql(upsert:)

      sql = <<~SQL.squish
        WITH raw_data(classification_tree_label_id, external_system_id, external_key, parent_external_key, name, name_i18n, description, description_i18n, uri, order_a, internal, assignable) AS (
          VALUES #{Array.new(sql_values.size, '(?::uuid, ?::uuid, ?::varchar, ?::varchar, ?::varchar, ?::jsonb, ?::varchar, ?::jsonb, ?::varchar, ?::integer, ?::boolean, ?::boolean)').join(', ')}
        ), data AS (
          SELECT DISTINCT * FROM raw_data
        ), inserted_c AS (
          INSERT INTO classifications (external_source_id, external_key, name, description, uri, created_at, updated_at)
          (SELECT external_system_id::uuid, external_key, name, description, uri, NOW(), NOW() FROM data)
          ON CONFLICT (external_source_id, external_key) WHERE deleted_at IS NULL AND external_key IS NOT NULL
            #{do_classifications}
          RETURNING *
        ), inserted_ca AS (
          INSERT INTO classification_aliases (external_source_id, external_key, internal_name, name_i18n, description_i18n, uri, order_a, created_at, updated_at#{', internal' if sets_internal}#{', assignable' if sets_assignable})
          (SELECT external_system_id::uuid, external_key, name, name_i18n, description_i18n, uri, order_a, NOW(), NOW()#{', internal' if sets_internal}#{', assignable' if sets_assignable} FROM data)
          ON CONFLICT (external_source_id, external_key) WHERE deleted_at IS NULL AND external_key IS NOT NULL
            #{do_classification_aliases}
          RETURNING *
        ), inserted_cg AS (
          INSERT INTO classification_groups (classification_id, classification_alias_id, external_source_id)
          (
            SELECT inserted_c.id, inserted_ca.id, inserted_c.external_source_id
            FROM inserted_c
            JOIN inserted_ca ON inserted_c.external_source_id IS NOT DISTINCT FROM inserted_ca.external_source_id
              AND inserted_c.external_key IS NOT DISTINCT FROM inserted_ca.external_key
          )
          ON CONFLICT (classification_id, classification_alias_id) WHERE deleted_at IS NULL
            DO NOTHING
        ), parent_ca AS (
          SELECT classification_aliases.id, classification_aliases.external_source_id, classification_aliases.external_key
          FROM data
          JOIN classification_aliases
            ON data.external_system_id IS NOT DISTINCT FROM classification_aliases.external_source_id AND
              data.parent_external_key IS NOT DISTINCT FROM classification_aliases.external_key AND
              classification_aliases.deleted_at IS NULL
          UNION
          SELECT inserted_ca.id, inserted_ca.external_source_id, inserted_ca.external_key
          FROM data
          JOIN inserted_ca
            ON data.external_system_id IS NOT DISTINCT FROM inserted_ca.external_source_id AND
              data.parent_external_key IS NOT DISTINCT FROM inserted_ca.external_key
        ), all_ca AS (
          SELECT classification_aliases.id, classification_aliases.external_source_id, classification_aliases.external_key
          FROM data
          JOIN classification_aliases
            ON data.external_system_id IS NOT DISTINCT FROM classification_aliases.external_source_id AND
              data.external_key IS NOT DISTINCT FROM classification_aliases.external_key AND
              classification_aliases.deleted_at IS NULL
          UNION
          SELECT inserted_ca.id, inserted_ca.external_source_id, inserted_ca.external_key
          FROM inserted_ca
        ), classification_trees_data AS (
          SELECT
            classification_tree_label_id, parent_ca.id parent_classification_alias_id, all_ca.id classification_alias_id, all_ca.external_source_id external_source_id,
            NOW() created_at, NOW() updated_at
          FROM all_ca
          JOIN data ON data.external_system_id IS NOT DISTINCT FROM all_ca.external_source_id AND data.external_key IS NOT DISTINCT FROM all_ca.external_key
          LEFT OUTER JOIN parent_ca ON data.external_system_id IS NOT DISTINCT FROM parent_ca.external_source_id AND
            data.parent_external_key = parent_ca.external_key
        ), inserted_ct AS (
          INSERT INTO classification_trees(classification_tree_label_id, parent_classification_alias_id, classification_alias_id, external_source_id, created_at, updated_at)
          (
            SELECT classification_trees_data.*
            FROM classification_trees_data
          )
          ON CONFLICT (classification_alias_id) WHERE deleted_at IS NULL
            #{do_classification_trees}
        )
        SELECT * FROM classification_trees_data;
      SQL

      ActiveRecord::Base.send(:sanitize_sql_array, [sql, *sql_values.flatten(1)])
    end

    def transform_row_data(row)
      return if row[:path].blank?
      raise 'classification_alias_path cannot contain blank values' if row[:path].include?(nil)

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
        row[:external_source_id]
      ]
    end

    def trigger_things_cache_invalidation?
      cached_attributes_changed?
    end

    # #50677: an update that also flips hidden_mappings is webhooked by refresh_hidden_mappings instead,
    # over the contents that *reach* the tree — a superset of `things`, so nothing is lost by stepping
    # aside here, while running both would deliver every directly classified content twice.
    def trigger_things_webhooks?
      trigger_webhooks? && cached_attributes_changed? && !saved_change_to_hidden_mappings?
    end

    def cached_attributes_changed?
      return @cached_attributes_changed if defined? @cached_attributes_changed

      # NB: hidden_mappings is deliberately absent — the contents it changes are the ones reaching this
      # tree through a mapping, which `things` (the directly classified contents) does not contain.
      # refresh_hidden_mappings handles them over the set it materialises CCC for.
      @cached_attributes_changed = saved_changes.key?('name') ||
                                   saved_changes.dig('visibility', 0)&.to_set&.^(saved_changes.dig('visibility', 1)&.to_set)&.include?('api')
    end

    def add_things_webhooks_job_update
      return unless things.exists?

      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'execute_things_webhooks')
    end

    # Invalidated from here rather than left to #invalidate_things_cache: that one lifts the directly
    # classified contents, not the ones linking them that the fan-out re-exports, and it runs in a
    # CacheInvalidationJob of its own with no ordering against this one.
    def execute_things_webhooks
      DataCycleCore::Content::RelatedWebhooks.fan_out(things, invalidate_related_cache: true)
    end

    def add_things_cache_invalidation_job_update
      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'invalidate_things_cache')
    end

    def invalidate_things_cache
      things.invalidate_all
    end

    def add_hidden_mappings_job_update
      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'refresh_hidden_mappings')
    end

    # Redmine #50677: collected_classification_contents.hidden is derived per (path, concept) from
    # this tree's hidden_mappings flag, so flipping it only has to re-materialise the CCC rows of this
    # tree's own concepts — not a single path row: classification_alias_paths_transitive.mapped_ids
    # ("reached through a mapping") is pure path structure and does not depend on the flag. Batched,
    # because a flagged tree can carry thousands of concepts and every batch touches all contents that
    # reach them.
    #
    # Search index and webhooks are refreshed from here, over the contents that reach the tree, rather than
    # through cached_attributes_changed? — its `things` are the *directly* classified contents, which
    # leaves out every content that only reaches the tree through a mapping, i.e. exactly the ones the
    # flag changes. cache_valid_since needs no help: invalidate_things_trigger on
    # collected_classification_contents bumps it for every non-'broader' row this rewrites, and a
    # content whose broader rows flip always has one — the mapped concept itself sorts deepest in its
    # path partition, so it holds the 'related' row and flips together with its ancestors.
    def refresh_hidden_mappings
      concept_ids = classification_aliases.reorder(nil).ids
      return if concept_ids.blank?

      affected_things = DataCycleCore::Thing.where(id: DataCycleCore::CollectedClassificationContent.where(classification_alias_id: concept_ids).select(:thing_id))

      if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
        concept_ids.each_slice(CCC_REFRESH_BATCH_SIZE) do |ids|
          execute_ccc_refresh('SELECT public.generate_ccc_from_ca_ids_transitive(ARRAY[?]::uuid[])', ids)
        end
      else
        affected_things.in_batches(of: CCC_REFRESH_BATCH_SIZE) do |batch|
          execute_ccc_refresh('SELECT public.generate_collected_classification_content_relations(ARRAY[?]::uuid[], ARRAY[]::uuid[])', batch.ids)
        end
      end

      enqueue_hidden_mappings_side_effects(affected_things)
    end

    # Fanned out rather than run inline: both are a find_each over a set the CCC half above has already
    # spent its batches on, so keeping them here would put six figures of re-indexing and webhook
    # deliveries behind a single job that restarts from zero — redoing nothing of the committed CCC work
    # but all of its own — on any failure.
    def enqueue_hidden_mappings_side_effects(affected_things)
      affected_things.in_batches(of: CCC_REFRESH_BATCH_SIZE).each_with_index do |batch, index|
        thing_ids = batch.ids

        # the batch index belongs in arguments[1]: CacheInvalidationDestroyJob dedups on
        # (queue, delayed_reference_id, delayed_reference_type) = (arguments[1], "class#method"), so a
        # bare id would make each batch delete the ones enqueued before it. Neither method reads it.
        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, "#{id}:#{index}", 'update_things_search', thing_ids)
        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, "#{id}:#{index}", 'execute_things_webhooks_destroy', thing_ids) if trigger_webhooks?
      end
    end

    def execute_ccc_refresh(sql, ids)
      return if ids.blank?

      self.class.transaction do
        self.class.connection.execute('SET LOCAL statement_timeout = 0')
        self.class.connection.execute(self.class.sanitize_sql([sql, ids]))
      end
    end

    def clean_stored_filters
      ActiveRecord::Base.connection.exec_query <<~SQL.squish
        WITH subquery AS
        (
            SELECT
              id,
              jsonb_agg( CASE
                WHEN jsonb_typeof( elem -> 'v' ) = 'array'
                THEN jsonb_set( elem,'{v}',( ( elem -> 'v' ) - '#{id}' ) )
                ELSE elem
            END ) AS new_parameters
            FROM
              collections ,
              jsonb_array_elements( parameters ) elem
            WHERE parameters::TEXT ILIKE '%#{id}%'
            GROUP BY id
        )
        UPDATE collections
        SET
          parameters = subquery.new_parameters FROM subquery
        WHERE collections.id = subquery.id
      SQL
    end
  end
end
