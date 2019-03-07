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

      belongs_to :thing

      def self.class_name
        'Thing' # TODO: check if this is really correct!!
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Thing::History', foreign_key: :thing_id, inverse_of: :thing
    has_many :searches, foreign_key: :content_data_id, dependent: :destroy, inverse_of: :content_data

    extend ::Translations
    translates :name, :description, :content, backend: :table
    default_scope { i18n }

    content_relations table_name: table_name

    has_many :thing_external_systems, dependent: :destroy
    has_many :external_systems, through: :thing_external_systems

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

    def translated_locales
      available_locales
      # if translations.loaded?
      #   translations.map(&:locale).sort
      # else
      #   translations.translated_locales
      # end
    end

    def cache_key
      [super, translations.in_locale(I18n.locale).cache_key].join('/') + '-' + I18n.locale.to_s
    end

    def self.class_name
      'Thing'
    end
  end
end
