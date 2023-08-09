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

          ClassificationGroup.create!(classification: classification,
                                      classification_alias: classification_alias)

          ClassificationTree.create!(classification_tree_label: self,
                                     parent_classification_alias: parent_classification_alias,
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

          ClassificationGroup.create!(classification: classification,
                                      classification_alias: classification_alias)

          ClassificationTree.create!(classification_tree_label: self,
                                     parent_classification_alias: parent_classification_alias,
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
        [
          "'#{id}'::uuid",
          "'#{external_source_id}'::uuid",
          "'#{row[:external_key]}'",
          "'#{row[:parent_external_key]}'",
          "'#{I18n.locale}'",
          "'#{row[:name]}'"
        ].join(',').sub!(/^(.*)$/, '(\\1)')
      }.join(',')

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(
          :sanitize_sql_array, [
            <<-SQL.squish
              WITH raw_data(classification_tree_label_id, external_system_id, external_key, parent_external_key, locale, name) AS (
                VALUES
                  #{sql_values}
              ), data AS (
                SELECT DISTINCT * FROM raw_data
              ), classifications AS (
                INSERT INTO classifications (external_source_id, external_key, name, created_at, updated_at)
                (SELECT external_system_id::uuid, external_key, name, NOW(), NOW() FROM data)
                ON CONFLICT (external_source_id, external_key) WHERE deleted_at IS NULL
                  DO UPDATE SET name = EXCLUDED.name, updated_at = NOW()
                RETURNING *
              ), classification_aliases AS (
                INSERT INTO classification_aliases (external_source_id, external_key, internal_name, name_i18n, created_at, updated_at)
                (SELECT external_system_id::uuid, external_key, name, ('{"' || locale || '":"' || name || '"}')::jsonb, NOW(), NOW() FROM data)
                ON CONFLICT (external_source_id, external_key) WHERE deleted_at IS NULL
                  DO UPDATE SET name_i18n = classification_aliases.name_i18n || EXCLUDED.name_i18n,
                    #{I18n.locale == I18n.available_locales.first ? 'internal_name = EXCLUDED.internal_name, ' : ''}
                    updated_at = NOW()
                RETURNING *
              ), classification_groups AS (
                INSERT INTO classification_groups (classification_id, classification_alias_id)
                (
                  SELECT classifications.id, classification_aliases.id
                  FROM classifications
                  JOIN classification_aliases ON classifications.external_source_id = classification_aliases.external_source_id
                    AND classifications.external_key = classification_aliases.external_key
                )
                ON CONFLICT (classification_id, classification_alias_id) WHERE deleted_at IS NULL
                  DO UPDATE SET updated_at = NOW()
                RETURNING *
              ), parent_classification_aliases AS (
                SELECT classification_aliases.id, classification_aliases.external_source_id, classification_aliases.external_key
                FROM data
                JOIN public.classification_aliases
                  ON data.external_system_id = classification_aliases.external_source_id AND
                    data.parent_external_key = classification_aliases.external_key
                UNION
                SELECT classification_aliases.id, classification_aliases.external_source_id, classification_aliases.external_key
                FROM data
                JOIN classification_aliases
                  ON data.external_system_id = classification_aliases.external_source_id AND
                    data.parent_external_key = classification_aliases.external_key
              ), classification_trees_data AS (
                SELECT
                  classification_tree_label_id, parent_classification_aliases.id "parent_classification_alias_id", classification_aliases.id "classification_alias_id",
                  NOW() "created_at", NOW() "updated_at"
                FROM classification_aliases
                JOIN data ON data.external_system_id = classification_aliases.external_source_id AND data.external_key = classification_aliases.external_key
                LEFT OUTER JOIN parent_classification_aliases ON data.external_system_id = parent_classification_aliases.external_source_id AND
                  data.parent_external_key = parent_classification_aliases.external_key
              ), classification_trees AS (
                INSERT INTO classification_trees(classification_tree_label_id, parent_classification_alias_id, classification_alias_id, created_at, updated_at)
                (
                  SELECT classification_trees_data.*
                  FROM classification_trees_data
                )
                ON CONFLICT (classification_alias_id) WHERE deleted_at IS NULL
                  DO UPDATE SET parent_classification_alias_id = EXCLUDED.parent_classification_alias_id,
                    classification_tree_label_id = EXCLUDED.classification_tree_label_id,
                    updated_at = NOW()
                RETURNING *
              )
              SELECT * FROM classification_trees_data;
            SQL
          ]
        )
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

    private

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
        content.send(:execute_update_webhooks)
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
