# frozen_string_literal: true

module DataCycleCore
  class Thing < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Thing
    include Content::ExternalData
    prepend Content::ContentOverlay

    class History < Content::Content
      include Content::ContentHistoryLoader
      include Content::Extensions::Thing
      include Content::Restorable
      prepend Content::ContentOverlay

      extend ::Translations
      translates :name, :description, :slug, :content, :history_valid, backend: :table
      default_scope { i18n }

      content_relations table_name: 'things', postfix: 'history'
      has_many :scheduled_history_data, class_name: 'DataCycleCore::Schedule::History', foreign_key: 'thing_history_id', dependent: :destroy, inverse_of: :thing_history

      belongs_to :thing

      def self.translated_locales
        DataCycleCore::Thing::History::Translation.where(translated_model: all).distinct.pluck(:locale).map(&:to_sym)
      end
    end

    class DuplicateCandidate < ApplicationRecord
      self.table_name = 'duplicate_candidates'

      belongs_to :original, class_name: 'DataCycleCore::Thing'
      belongs_to :duplicate, class_name: 'DataCycleCore::Thing'
      belongs_to :thing_duplicate

      def self.thing_duplicates
        DataCycleCore::ThingDuplicate.where(id: all.pluck(:thing_duplicate_id))
      end

      def self.duplicates
        DataCycleCore::Thing.where(id: all.pluck(:duplicate_id))
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

    has_many :histories, -> { joins(:translations).order(Arel.sql('LOWER(thing_history_translations.history_valid) DESC, thing_history_translations.created_at DESC')) }, class_name: 'DataCycleCore::Thing::History', foreign_key: :thing_id, inverse_of: :thing
    has_many :scheduled_data, class_name: 'DataCycleCore::Schedule', dependent: :destroy, inverse_of: :thing

    has_many :duplicate_candidates, -> { where(false_positive: false).order(score: :desc) }, class_name: 'DuplicateCandidate', foreign_key: :original_id, inverse_of: :original
    has_many :duplicates, through: :duplicate_candidates, source: :duplicate
    has_many :thing_duplicates, dependent: :destroy
    has_many :thing_originals, class_name: 'DataCycleCore::ThingDuplicate', foreign_key: :thing_duplicate_id, dependent: :destroy, inverse_of: :original

    has_many :searches, foreign_key: :content_data_id, dependent: :destroy, inverse_of: :content_data

    extend ::Translations
    translates :name, :description, :slug, :content, backend: :table
    default_scope { i18n }

    content_relations table_name: table_name

    has_many :external_system_syncs, as: :syncable, dependent: :destroy, inverse_of: :syncable
    has_many :external_systems, through: :external_system_syncs

    has_many :activities, as: :activitiable, dependent: :destroy
    has_many :timeseries, class_name: 'DataCycleCore::Timeseries', dependent: :destroy, inverse_of: :thing

    def self.translated_locales
      DataCycleCore::Thing::Translation.where(translated_model: all).distinct.pluck(:locale)
    end

    def cache_key
      [super, translations.in_locale(I18n.locale).cache_key].join('/') + '-' + I18n.locale.to_s
    end
  end
end
