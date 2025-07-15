# frozen_string_literal: true

module DataCycleCore
  class Thing < Content::DataHash
    include Content::ContentRelations
    include Content::ContentLoader
    include Content::Extensions::OptimizedContentContents
    include Content::ExternalData
    prepend Content::ContentOverlay

    class History < Content::Content
      include Content::ContentRelations
      include Content::ContentHistoryLoader
      include Content::Restorable
      prepend Content::ContentOverlay

      extend ::Mobility
      translates :slug, :content, backend: :table
      default_scope { i18n.includes(:thing_template) }

      has_many :scheduled_history_data, class_name: 'DataCycleCore::Schedule::History', foreign_key: 'thing_history_id', dependent: :destroy, inverse_of: :thing_history

      belongs_to :thing
      has_many :content_collection_link_histories, dependent: :delete_all, foreign_key: :thing_history_id, inverse_of: :thing_history
      has_many :thing_history_links, dependent: :nullify, foreign_key: :thing_history_id, inverse_of: :thing_history
      has_many :geometry_histories, dependent: :delete_all, inverse_of: :thing_history

      def available_locales
        I18n.available_locales.intersection(translations.select(&:persisted?).pluck(:locale).map(&:to_sym))
      end
      alias translated_locales available_locales

      def self.translated_locales
        DataCycleCore::Thing::History::Translation.where(thing_history_id: pluck(:id)).distinct.pluck(:locale).map(&:to_sym)
      end
    end

    class DuplicateCandidate < ApplicationRecord
      self.table_name = 'duplicate_candidates'

      belongs_to :original, class_name: 'DataCycleCore::Thing'
      belongs_to :duplicate, class_name: 'DataCycleCore::Thing'
      belongs_to :thing_duplicate

      def self.thing_duplicates
        DataCycleCore::ThingDuplicate.where(id: pluck(:thing_duplicate_id))
      end

      def self.duplicates
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
    has_many :thing_duplicates, dependent: :delete_all
    has_many :thing_originals, class_name: 'DataCycleCore::ThingDuplicate', foreign_key: :thing_duplicate_id, dependent: :delete_all, inverse_of: :original

    has_many :searches, foreign_key: :content_data_id, dependent: :destroy, inverse_of: :content_data

    has_many :thing_history_links, dependent: :delete_all, class_name: 'DataCycleCore::ThingHistoryLink', inverse_of: :thing

    extend ::Mobility
    translates :slug, :content, backend: :table
    default_scope { i18n.includes(:thing_template) }

    has_many :external_system_syncs, as: :syncable, dependent: :destroy, inverse_of: :syncable, autosave: true
    has_many :external_systems, through: :external_system_syncs

    has_many :activities, as: :activitiable, dependent: :destroy
    has_many :timeseries, class_name: 'DataCycleCore::Timeseries', dependent: :delete_all, inverse_of: :thing

    has_many :schedules
    has_many :collected_classification_contents
    has_many :related_classification_contents, -> { related }, inverse_of: false, class_name: 'DataCycleCore::CollectedClassificationContent'
    has_many :full_classification_contents, -> { without_broader }, inverse_of: false, class_name: 'DataCycleCore::CollectedClassificationContent'
    has_many :full_classification_aliases, through: :full_classification_contents, class_name: 'DataCycleCore::ClassificationAlias', source: :classification_alias
    has_many :full_classification_tree_labels, through: :full_classification_contents, class_name: 'DataCycleCore::ClassificationTreeLabel', source: :classification_tree_label
    has_many :content_collection_links, dependent: :delete_all
    has_many :geometries, dependent: :delete_all, inverse_of: :thing, autosave: true
    has_one :primary_geometry, -> { primary }, class_name: 'DataCycleCore::Geometry', inverse_of: false, foreign_key: :thing_id

    scope :duplicate_candidates, -> { DataCycleCore::Thing::DuplicateCandidate.where(original_id: select(:id).reorder(nil)).where(false_positive: false).order(score: :desc) }

    def available_locales
      I18n.available_locales.intersection(translations.select(&:persisted?).pluck(:locale).map(&:to_sym))
    end
    alias translated_locales available_locales

    def self.translated_locales
      DataCycleCore::Thing::Translation.where(thing_id: pluck(:id)).distinct.pluck(:locale)
    end

    def cache_key
      "#{[super, translations.in_locale(I18n.locale).cache_key].join('/')}-#{I18n.locale}"
    end
  end
end
