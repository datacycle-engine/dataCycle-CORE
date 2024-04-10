# frozen_string_literal: true

module DataCycleCore
  class Thing < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Thing
    include Content::Extensions::OptimizedContentContents
    include Content::ExternalData
    prepend Content::ContentOverlay

    class History < Content::Content
      include Content::ContentHistoryLoader
      include Content::Extensions::Thing
      include Content::Restorable
      prepend Content::ContentOverlay

      extend ::Mobility
      translates :slug, :content, backend: :table
      default_scope { i18n.includes(:thing_template) }

      content_relations table_name: 'things', postfix: 'history'
      has_many :scheduled_history_data, class_name: 'DataCycleCore::Schedule::History', foreign_key: 'thing_history_id', dependent: :destroy, inverse_of: :thing_history

      belongs_to :thing
      has_many :content_collection_link_histories, dependent: :delete_all, foreign_key: :thing_history_id, inverse_of: :thing_history

      def available_locales
        I18n.available_locales.intersection(translations.select(&:persisted?).pluck(:locale).map(&:to_sym))
      end
      alias translated_locales available_locales

      def self.translated_locales
        return DataCycleCore::Thing::History::Translation.none if all.is_a?(ActiveRecord::NullRelation)

        DataCycleCore::Thing::History::Translation.where(translated_model: all).distinct.pluck(:locale).map(&:to_sym)
      end
    end

    class DuplicateCandidate < ApplicationRecord
      self.table_name = 'duplicate_candidates'

      belongs_to :original, class_name: 'DataCycleCore::Thing'
      belongs_to :duplicate, class_name: 'DataCycleCore::Thing'
      belongs_to :thing_duplicate

      def self.thing_duplicates
        return DataCycleCore::ThingDuplicate.none if all.is_a?(ActiveRecord::NullRelation)

        DataCycleCore::ThingDuplicate.where(id: pluck(:thing_duplicate_id))
      end

      def self.duplicates
        return DataCycleCore::Thing.none if all.is_a?(ActiveRecord::NullRelation)

        DataCycleCore::Thing.where(id: pluck(:duplicate_id))
      end

      def self.with_fp
        unscope(where: :false_positive)
      end

      def readonly?
        true
      end
    end

    class PropertyDependency < ApplicationRecord
      self.table_name = 'content_property_dependencies'

      belongs_to :thing, foreign_key: :content_id, class_name: 'DataCycleCore::Thing', inverse_of: :property_dependencies
      belongs_to :dependent_thing, foreign_key: :dependent_content_id, class_name: 'DataCycleCore::Thing', inverse_of: :dependent_properties

      def readonly?
        true
      end
    end

    has_many :property_dependencies, class_name: 'PropertyDependency', inverse_of: :thing, foreign_key: :content_id
    has_many :dependent_properties, class_name: 'PropertyDependency', inverse_of: :dependent_thing, foreign_key: :dependent_content_id

    has_many :histories, -> { joins(:translations).order(updated_at: :desc, created_at: :desc) }, class_name: 'DataCycleCore::Thing::History', foreign_key: :thing_id, inverse_of: :thing
    has_many :scheduled_data, class_name: 'DataCycleCore::Schedule', dependent: :destroy, inverse_of: :thing

    has_many :duplicate_candidates, -> { where(false_positive: false).order(score: :desc) }, class_name: 'DuplicateCandidate', foreign_key: :original_id, inverse_of: :original
    has_many :duplicates, through: :duplicate_candidates, source: :duplicate
    has_many :thing_duplicates, dependent: :destroy
    has_many :thing_originals, class_name: 'DataCycleCore::ThingDuplicate', foreign_key: :thing_duplicate_id, dependent: :destroy, inverse_of: :original

    has_many :searches, foreign_key: :content_data_id, dependent: :destroy, inverse_of: :content_data

    extend ::Mobility
    translates :slug, :content, backend: :table
    default_scope { i18n.includes(:thing_template) }

    content_relations(table_name:)

    has_many :external_system_syncs, as: :syncable, dependent: :destroy, inverse_of: :syncable
    has_many :external_systems, through: :external_system_syncs

    has_many :activities, as: :activitiable, dependent: :destroy
    has_many :timeseries, class_name: 'DataCycleCore::Timeseries', dependent: :destroy, inverse_of: :thing

    has_many :schedules
    has_many :collected_classification_contents
    has_many :content_collection_links, dependent: :delete_all

    scope :duplicate_candidates, -> { DataCycleCore::Thing::DuplicateCandidate.where(original_id: select(:id).reorder(nil)).where(false_positive: false).order(score: :desc) }

    def available_locales
      I18n.available_locales.intersection(translations.select(&:persisted?).pluck(:locale).map(&:to_sym))
    end
    alias translated_locales available_locales

    def self.translated_locales
      return DataCycleCore::Thing::Translation.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::Thing::Translation.where(translated_model: all).distinct.pluck(:locale)
    end

    def cache_key
      [super, translations.in_locale(I18n.locale).cache_key].join('/') + '-' + I18n.locale.to_s
    end
  end
end
