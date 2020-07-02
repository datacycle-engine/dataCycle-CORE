# frozen_string_literal: true

module DataCycleCore
  class Thing < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Thing
    include Content::ExternalData

    class History < Content::Content
      include Content::ContentHistoryLoader

      extend ::Translations
      translates :name, :description, :content, :history_valid, backend: :table
      default_scope { i18n }

      content_relations table_name: 'things', postfix: 'history'
      has_many :scheduled_history_data, class_name: 'DataCycleCore::Schedule::History', foreign_key: 'thing_history_id', dependent: :destroy, inverse_of: :thing_history

      belongs_to :thing
    end

    class DuplicateCandidate < ApplicationRecord
      self.table_name = 'duplicate_candidates'

      belongs_to :original, class_name: 'DataCycleCore::Thing'
      belongs_to :duplicate, class_name: 'DataCycleCore::Thing'
      belongs_to :thing_duplicate

      def self.with_fp
        unscope(where: :false_positive)
      end

      def readonly?
        true
      end
    end

    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Thing::History', foreign_key: :thing_id, inverse_of: :thing
    has_many :scheduled_data, class_name: 'DataCycleCore::Schedule', dependent: :destroy, inverse_of: :thing

    has_many :duplicate_candidates, -> { where(false_positive: false).order(score: :asc) }, class_name: 'DuplicateCandidate', foreign_key: :original_id, inverse_of: :original
    has_many :duplicates, through: :duplicate_candidates, source: :duplicate
    has_many :thing_duplicates, dependent: :destroy
    has_many :thing_originals, class_name: 'DataCycleCore::ThingDuplicate', foreign_key: :thing_duplicate_id, dependent: :destroy, inverse_of: :original

    has_many :searches, foreign_key: :content_data_id, dependent: :destroy, inverse_of: :content_data

    extend ::Translations
    translates :name, :description, :content, backend: :table
    default_scope { i18n }

    content_relations table_name: table_name

    has_many :external_system_syncs, as: :syncable, dependent: :destroy, inverse_of: :syncable
    has_many :external_systems, through: :external_system_syncs

    has_many :activities, as: :activitiable, dependent: :destroy

    def self.with_classification_alias_ids(classification_alias_ids)
      classification_alias_ids = Array(classification_alias_ids).map { |id|
        "'#{id}'"
      }.join(',')

      virtual_table_name = "contents_#{SecureRandom.hex}"

      joins(
        <<-SQL.gsub(/\s+/, ' ')
          JOIN (
            WITH RECURSIVE recursive_classification_trees AS (
              SELECT *
              FROM classification_trees
              WHERE classification_trees.parent_classification_alias_id IN (#{classification_alias_ids})
              OR classification_trees.classification_alias_id IN (#{classification_alias_ids})
              UNION ALL
              SELECT classification_trees.*
              FROM classification_trees
              INNER JOIN recursive_classification_trees
                ON classification_trees.parent_classification_alias_id = recursive_classification_trees.classification_alias_id
            )
            SELECT DISTINCT content_data_id
            FROM classification_contents
            JOIN classification_groups
              ON classification_contents.classification_id = classification_groups.classification_id
            JOIN recursive_classification_trees
              ON recursive_classification_trees.classification_alias_id = classification_groups.classification_alias_id
            WHERE classification_groups.deleted_at IS NULL AND recursive_classification_trees.deleted_at IS NULL
          ) AS #{virtual_table_name}
            ON things.id = #{virtual_table_name}.content_data_id
        SQL
      )
    end

    def self.without_classification_alias_ids(classification_alias_ids)
      classification_alias_ids = Array(classification_alias_ids).map { |id|
        "'#{id}'"
      }.join(',')

      virtual_table_name = "contents_#{SecureRandom.hex}"

      where(
        <<-SQL.gsub(/\s+/, ' ')
          things.id NOT IN (
            WITH #{virtual_table_name} AS (
              WITH recursive recursive_classification_trees AS (
                    SELECT *
                    FROM   classification_trees
                    WHERE  classification_trees.parent_classification_alias_id IN (#{classification_alias_ids})
                    OR     classification_trees.classification_alias_id        IN (#{classification_alias_ids})
                    UNION ALL
                    SELECT     classification_trees.*
                    FROM       classification_trees
                    inner join recursive_classification_trees
                    ON         classification_trees.parent_classification_alias_id = recursive_classification_trees.classification_alias_id
              ) SELECT DISTINCT content_data_id
              FROM classification_contents
              join classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              join recursive_classification_trees ON recursive_classification_trees.classification_alias_id = classification_groups.classification_alias_id
              WHERE classification_groups.deleted_at IS NULL
                  AND recursive_classification_trees.deleted_at IS NULL
            )
            SELECT content_data_id FROM #{virtual_table_name}
          )
        SQL
      )
    end

    def self.translated_locales
      DataCycleCore::Thing::Translation.where(translated_model: all).distinct.pluck(:locale)
    end

    def cache_key
      [super, translations.in_locale(I18n.locale).cache_key].join('/') + '-' + I18n.locale.to_s
    end
  end
end
