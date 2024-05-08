# frozen_string_literal: true

require 'csv'

module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord
    validates :name, presence: true

    after_update :add_things_cache_invalidation_job_update, if: :trigger_things_cache_invalidation?
    after_update :add_things_webhooks_job_update, if: :trigger_things_webhooks?

    acts_as_paranoid

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'

    has_many :classification_trees, dependent: :destroy
    has_many :classification_aliases, through: :classification_trees, source: :sub_classification_alias do
      def roots
        joins(:classification_tree).where(classification_trees: { parent_classification_alias_id: nil })
      end
    end

    has_one :concept_scheme, foreign_key: :id, dependent: nil, inverse_of: :classification_tree_label

    has_many :classification_aliases_with_deleted, -> { with_deleted }, through: :classification_trees, source: :sub_classification_alias

    has_many :classifications, through: :classification_aliases
    has_many :things, -> { unscope(:order).distinct }, through: :classifications

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
        if parent_classification_alias
          classification_alias = parent_classification_alias
            .sub_classification_alias
            .find_or_initialize_by(name: attributes[:name], external_source: attributes[:external_source], uri: attributes[:uri])
        else
          classification_alias = classification_aliases.roots
            .find_or_initialize_by(name: attributes[:name], external_source: attributes[:external_source], uri: attributes[:uri])
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
        if parent_classification_alias
          classification_alias = parent_classification_alias
            .sub_classification_alias
            .find_or_initialize_by(name: attributes[:name])
        else
          classification_alias = classification_aliases.roots
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

    def upsert_all_external_classifications(attributes)
      sql_values = attributes.compact_blank.map { |row|
        next if row[:name].blank?

        [
          id,
          row[:external_source_id].presence || external_source_id,
          row[:external_key],
          row[:parent_external_key],
          I18n.locale,
          row[:name],
          row[:description],
          row[:uri],
          row[:order_a]
        ]
      }.compact

      sql = <<-SQL.squish
        WITH raw_data(classification_tree_label_id, external_system_id, external_key, parent_external_key, locale, name, description, uri, order_a) AS (
          VALUES #{Array.new(sql_values.size, '(?::uuid, ?::uuid, ?::varchar, ?::varchar, ?::varchar, ?::varchar, ?::varchar, ?::varchar, ?::integer)').join(', ')}
        ), data AS (
          SELECT DISTINCT * FROM raw_data
        ), inserted_c AS (
          INSERT INTO classifications (external_source_id, external_key, name, description, uri, created_at, updated_at)
          (SELECT external_system_id::uuid, external_key, name, description, uri, NOW(), NOW() FROM data)
          ON CONFLICT (external_source_id, external_key) WHERE deleted_at IS NULL
            DO UPDATE SET #{I18n.locale == I18n.available_locales.first ? 'name = EXCLUDED.name, ' : ''}
            #{I18n.locale == I18n.available_locales.first ? 'description = EXCLUDED.description, ' : ''}
            #{I18n.locale == I18n.available_locales.first ? 'uri = EXCLUDED.uri, ' : ''}
            updated_at = NOW()
          RETURNING *
        ), inserted_ca AS (
          INSERT INTO classification_aliases (external_source_id, external_key, internal_name, name_i18n, description_i18n, uri, order_a, created_at, updated_at)
          (SELECT external_system_id::uuid, external_key, name, jsonb_strip_nulls(jsonb_build_object(locale, name)), jsonb_strip_nulls(jsonb_build_object(locale, description)), uri, order_a, NOW(), NOW() FROM data)
          ON CONFLICT (external_source_id, external_key) WHERE deleted_at IS NULL
            DO UPDATE SET
              name_i18n = coalesce(classification_aliases.name_i18n, '{}'::jsonb) || coalesce(EXCLUDED.name_i18n, '{}'::jsonb),
              description_i18n = coalesce(classification_aliases.description_i18n, '{}'::jsonb) || coalesce(EXCLUDED.description_i18n, '{}'::jsonb),
              #{I18n.locale == I18n.available_locales.first ? 'internal_name = EXCLUDED.internal_name, ' : ''}
              uri = EXCLUDED.uri,
              order_a = EXCLUDED.order_a,
              updated_at = NOW()
          RETURNING *
        ), inserted_cg AS (
          INSERT INTO classification_groups (classification_id, classification_alias_id)
          (
            SELECT inserted_c.id, inserted_ca.id
            FROM inserted_c
            JOIN inserted_ca ON inserted_c.external_source_id = inserted_ca.external_source_id
              AND inserted_c.external_key = inserted_ca.external_key
          )
          ON CONFLICT (classification_id, classification_alias_id) WHERE deleted_at IS NULL
            DO UPDATE SET updated_at = NOW()
        ), parent_ca AS (
          SELECT classification_aliases.id, classification_aliases.external_source_id, classification_aliases.external_key
          FROM data
          JOIN classification_aliases
            ON data.external_system_id = classification_aliases.external_source_id AND
              data.parent_external_key = classification_aliases.external_key AND
              classification_aliases.deleted_at IS NULL
          UNION
          SELECT inserted_ca.id, inserted_ca.external_source_id, inserted_ca.external_key
          FROM data
          JOIN inserted_ca
            ON data.external_system_id = inserted_ca.external_source_id AND
              data.parent_external_key = inserted_ca.external_key
        ), classification_trees_data AS (
          SELECT
            classification_tree_label_id, parent_ca.id parent_classification_alias_id, inserted_ca.id classification_alias_id,
            NOW() created_at, NOW() updated_at
          FROM inserted_ca
          JOIN data ON data.external_system_id = inserted_ca.external_source_id AND data.external_key = inserted_ca.external_key
          LEFT OUTER JOIN parent_ca ON data.external_system_id = parent_ca.external_source_id AND
            data.parent_external_key = parent_ca.external_key
        ), inserted_ct AS (
          INSERT INTO classification_trees(classification_tree_label_id, parent_classification_alias_id, classification_alias_id, created_at, updated_at)
          (
            SELECT classification_trees_data.*
            FROM classification_trees_data
          )
          ON CONFLICT (classification_alias_id) WHERE deleted_at IS NULL
            DO UPDATE SET parent_classification_alias_id = EXCLUDED.parent_classification_alias_id,
              classification_tree_label_id = EXCLUDED.classification_tree_label_id,
              updated_at = NOW()
        )
        SELECT * FROM classification_trees_data;
      SQL

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, *sql_values.flatten(1)])
      )
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

      sql_values.each do |v|
        v[3].reverse!
        v[4].reverse!
      end

      sql = <<-SQL.squish
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

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, *sql_values.flatten(1)])
      )
    end

    def to_csv(include_contents: false)
      CSV.generate do |csv|
        csv << [name]
        classification_aliases.includes(:classification_alias_path, :classifications).sort_by(&:full_path).each do |classification_alias|
          csv << Array.new(classification_alias.ancestors.count) + [classification_alias.name]

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
        classification_aliases.includes(:classification_alias_path).map(&:full_path).sort.each { |fp| csv << [fp] }
      end
    end

    def to_csv_with_mappings
      CSV.generate do |csv|
        csv << ['Pfad zur Klassifizierung', 'Pfad zu gemappter Klassifizierung']
        classification_aliases.includes(:classification_alias_path, additional_classifications: [primary_classification_alias: :classification_alias_path]).reorder(nil).order('array_reverse(classification_alias_paths.full_path_names) ASC').references(:classification_alias_path).find_each do |ca|
          ca.additional_classifications.map(&:primary_classification_alias).each do |mapped_ca|
            csv << [ca.full_path, mapped_ca.full_path]
          end
        end
      end
    end

    def to_csv_with_inverse_mappings
      CSV.generate do |csv|
        csv << ['Pfad zur Klassifizierung', 'Pfad zu gemappter Klassifizierung']
        classification_aliases.includes(:classification_alias_path, primary_classification: [additional_classification_aliases: :classification_alias_path]).reorder(nil).order('array_reverse(classification_alias_paths.full_path_names) ASC').references(:classification_alias_path).find_each do |ca|
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
      visibility.include?(context)
    end

    def self.visible(context)
      where('? = ANY(visibility)', context)
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
      raw_sql = <<-SQL.squish
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

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            raw_sql,
            id:
          ]
        )
      )
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id,
        ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon classification_tree_label-icon'),
          name
        ].compact, ' '),
        model_name.param_key,
        "#{model_name.human(count: 1, locale:)}: #{name}"
      )
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first)
      all.map { |v| v.to_select_option(locale) }
    end

    private

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

    def trigger_things_webhooks?
      change_behaviour&.include?('trigger_webhooks') && cached_attributes_changed?
    end

    def cached_attributes_changed?
      return @cached_attributes_changed if defined? @cached_attributes_changed

      @cached_attributes_changed = saved_changes.key?('name') ||
                                   saved_changes.dig('visibility', 0)&.to_set&.^(saved_changes.dig('visibility', 1)&.to_set)&.include?('api')
    end

    def add_things_webhooks_job_update
      return unless things.exists?

      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'execute_things_webhooks')
    end

    def execute_things_webhooks
      things.find_each do |content|
        content.send(:execute_update_webhooks) unless content.embedded?
      end
    end

    def add_things_cache_invalidation_job_update
      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'invalidate_things_cache')
    end

    def invalidate_things_cache
      things.invalidate_all
    end
  end
end
