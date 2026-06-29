# frozen_string_literal: true

module DataCycleCore
  class Thing < Content::DataHash
    include Content::ContentRelations
    include Content::ContentLoader
    include Content::Extensions::OptimizedContentContents
    include Content::ExternalData
    prepend Content::ContentOverlay
    include Content::Extensions::TemplateModels
    include Content::Extensions::TemplateConversion

    class History < Content::Content
      include Content::ContentRelations
      include Content::ContentHistoryLoader
      include Content::Restorable
      prepend Content::ContentOverlay
      include Content::Extensions::TemplateModels
      include Content::Extensions::TemplateConversion

      extend ::Mobility

      translates :slug, :content, backend: :table
      # Mobility hardcodes dependent: :destroy (one query per translation);
      # redeclared with :delete_all, the rows are covered by FK ON DELETE CASCADE anyway
      has_many :translations,
               class_name: 'DataCycleCore::Thing::History::Translation',
               foreign_key: :thing_history_id,
               inverse_of: :translated_model,
               autosave: true,
               dependent: :delete_all,
               extend: ::Mobility::Backends::ActiveRecord::Table::TranslationsHasManyExtension
      default_scope { i18n.includes(:thing_template) }

      # deleted by FK ON DELETE CASCADE (thing_history_id): scheduled_history_data,
      # content_collection_link_histories, geometry_histories, embedding_histories
      # rubocop:disable Rails/HasManyOrHasOneDependent
      has_many :scheduled_history_data, class_name: 'DataCycleCore::Schedule::History', foreign_key: 'thing_history_id', inverse_of: :thing_history

      belongs_to :thing
      has_many :content_collection_link_histories, class_name: 'DataCycleCore::ContentCollectionLinkHistory', foreign_key: :thing_history_id, inverse_of: :thing_history
      # :nullify must stay: it runs before the delete and preempts the FK ON DELETE CASCADE
      has_many :thing_history_links, class_name: 'DataCycleCore::ThingHistoryLink', dependent: :nullify, foreign_key: :thing_history_id, inverse_of: :thing_history
      has_many :geometry_histories, class_name: 'DataCycleCore::GeometryHistory', inverse_of: :thing_history
      has_many :embedding_histories, class_name: 'DataCycleCore::EmbeddingHistory', inverse_of: :thing_history
      # rubocop:enable Rails/HasManyOrHasOneDependent

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

      scope :without_thing_method_pairs, ->(value) { where.not(Array.wrap(value).map { 'original_id = ? AND duplicate_method = ?' }.join(' OR '), *Array.wrap(value).flatten) }

      def self.thing_duplicates
        DataCycleCore::ThingDuplicate.where(id: pluck(:thing_duplicate_id))
      end

      def self.duplicates
        DataCycleCore::Thing.where(id: pluck(:duplicate_id))
      end

      def self.with_fp
        unscope(where: :false_positive).where(false_positive: true)
      end

      def self.without_fp
        where(false_positive: false)
      end

      def readonly?
        true
      end

      def duplicate_module
        @duplicate_module ||= Utility::DuplicateCandidate::Base.by_identifier(duplicate_method)
      end
    end

    # Only for computed properties
    class PropertyDependency < ApplicationRecord
      self.table_name = 'content_property_dependencies'

      belongs_to :thing, foreign_key: :content_id, class_name: 'DataCycleCore::Thing', inverse_of: :property_dependencies
      belongs_to :dependent_thing, foreign_key: :dependent_content_id, class_name: 'DataCycleCore::Thing', inverse_of: :dependent_properties

      def readonly?
        true
      end

      def self.id_attribute_hash(dependent_content_id)
        dependent_ids = where(dependent_content_id:).distinct.pluck(:content_id, :property_name)
        return {} if dependent_ids.blank?

        id_attribute_hash = Hash.new { |h, k| h[k] = [] }
        dependent_ids.each do |dep_id, prop_name|
          id_attribute_hash[dep_id] << prop_name
        end

        id_attribute_hash
      end
    end

    has_many :property_dependencies, class_name: 'DataCycleCore::Thing::PropertyDependency', inverse_of: :thing, foreign_key: :content_id
    has_many :dependent_properties, class_name: 'DataCycleCore::Thing::PropertyDependency', inverse_of: :dependent_thing, foreign_key: :dependent_content_id

    has_many :histories, -> { joins(:translations).order(updated_at: :desc, created_at: :desc) }, class_name: 'DataCycleCore::Thing::History', foreign_key: :thing_id, inverse_of: :thing
    # deleted by FK ON DELETE CASCADE (thing_id)
    has_many :scheduled_data, class_name: 'DataCycleCore::Schedule', inverse_of: :thing

    has_many :duplicate_candidates, -> { where(false_positive: false).order(score: :desc) }, class_name: 'DataCycleCore::Thing::DuplicateCandidate', foreign_key: :original_id, inverse_of: :original
    has_many :duplicates, through: :duplicate_candidates, source: :duplicate
    has_many :thing_duplicates, class_name: 'DataCycleCore::ThingDuplicate'
    has_many :thing_originals, class_name: 'DataCycleCore::ThingDuplicate', foreign_key: :thing_duplicate_id, inverse_of: :original

    # deleted by FK ON DELETE CASCADE (content_data_id)
    has_many :searches, class_name: 'DataCycleCore::Search', foreign_key: :content_data_id, inverse_of: :content_data

    has_many :thing_history_links, class_name: 'DataCycleCore::ThingHistoryLink', inverse_of: :thing

    extend ::Mobility

    translates :slug, :content, backend: :table
    # Mobility hardcodes dependent: :destroy (one query per translation);
    # redeclared with :delete_all, the rows are covered by FK ON DELETE CASCADE anyway
    has_many :translations,
             class_name: 'DataCycleCore::Thing::Translation',
             inverse_of: :translated_model,
             autosave: true,
             dependent: :delete_all,
             extend: ::Mobility::Backends::ActiveRecord::Table::TranslationsHasManyExtension
    default_scope { i18n.includes(:thing_template) }

    # polymorphic, no FK possible => :delete_all (single query, no callbacks to run)
    has_many :external_system_syncs, as: :syncable, dependent: :delete_all, inverse_of: :syncable, autosave: true, class_name: 'DataCycleCore::ExternalSystemSync'
    has_many :external_systems, through: :external_system_syncs, class_name: 'DataCycleCore::ExternalSystem'

    # polymorphic, no FK possible => :delete_all (single query, no callbacks to run)
    has_many :activities, as: :activitiable, dependent: :delete_all, class_name: 'DataCycleCore::Activity'
    has_many :timeseries, class_name: 'DataCycleCore::Timeseries', inverse_of: :thing

    has_many :schedules, class_name: 'DataCycleCore::Schedule'
    has_many :collected_classification_contents, class_name: 'DataCycleCore::CollectedClassificationContent'
    has_many :related_classification_contents, -> { related }, inverse_of: false, class_name: 'DataCycleCore::CollectedClassificationContent'
    has_many :full_classification_contents, -> { without_broader }, inverse_of: false, class_name: 'DataCycleCore::CollectedClassificationContent'
    has_many :full_classification_aliases, through: :full_classification_contents, class_name: 'DataCycleCore::ClassificationAlias', source: :classification_alias
    has_many :full_classification_tree_labels, through: :full_classification_contents, class_name: 'DataCycleCore::ClassificationTreeLabel', source: :classification_tree_label
    has_many :content_collection_links, class_name: 'DataCycleCore::ContentCollectionLink'
    has_many :geometries, class_name: 'DataCycleCore::Geometry', inverse_of: :thing, autosave: true
    has_many :embeddings, class_name: 'DataCycleCore::Embedding', inverse_of: :thing
    has_one :primary_geometry, -> { primary }, class_name: 'DataCycleCore::Geometry', inverse_of: false, foreign_key: :thing_id

    has_many :content_content_links_a, -> { with_relation }, class_name: 'DataCycleCore::ContentContent::Link', foreign_key: :content_a_id, inverse_of: :content_a
    has_many :ccl_content_bs, through: :content_content_links_a, source: :content_b, class_name: 'DataCycleCore::Thing'
    has_many :content_content_links_b, -> { with_relation }, class_name: 'DataCycleCore::ContentContent::Link', foreign_key: :content_b_id, inverse_of: :content_b
    has_many :ccl_content_as, through: :content_content_links_b, source: :content_a, class_name: 'DataCycleCore::Thing'

    has_many :stored_filter_caches, class_name: 'DataCycleCore::StoredFilterCache', inverse_of: :thing

    def available_locales
      I18n.available_locales.intersection(translations.select(&:persisted?).pluck(:locale).map(&:to_sym))
    end
    alias translated_locales available_locales

    def translation_updated_at(locale = I18n.locale)
      translations.in_locale(locale)&.updated_at
    end

    def self.translated_locales
      DataCycleCore::Thing::Translation.where(thing_id: pluck(:id)).distinct.pluck(:locale)
    end

    def self.duplicate_candidates
      DataCycleCore::Thing::DuplicateCandidate
        .where(original_id: select(:id).reorder(nil))
        .where(false_positive: false)
        .order(score: :desc)
    end

    def cache_key
      "#{[super, translations.in_locale(I18n.locale).cache_key].join('/')}-#{I18n.locale}"
    end

    def create_duplicate(current_user: nil)
      new_content = DataCycleCore::Thing.new(template_name: template_name)
      return if blank? || !content_type?('entity')

      available_locales.each do |locale|
        I18n.with_locale(locale) do
          ActiveRecord::Base.transaction do
            created = new_content.new_record?
            new_content.save!
            new_content_datahash = duplicate_data_hash(get_data_hash).merge({ name: "DUPLICATE: #{title}" })
            valid = new_content.set_data_hash(data_hash: new_content_datahash, current_user:, new_content: created)

            raise ActiveRecord::Rollback, 'dataHash errors found' unless valid
          end
        end
      end

      return unless new_content.persisted?

      new_content.reload
    end
  end
end
