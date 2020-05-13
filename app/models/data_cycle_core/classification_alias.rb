# frozen_string_literal: true

module DataCycleCore
  class ClassificationAlias < ApplicationRecord
    class Path < ApplicationRecord
      self.table_name = 'classification_alias_paths'

      belongs_to :classification_alias, foreign_key: 'id'

      def readonly?
        true
      end
    end

    class Statistics < ApplicationRecord
      self.table_name = 'classification_alias_statistics'

      belongs_to :classification_alias, foreign_key: 'id'

      def readonly?
        true
      end
    end

    extend ::Translations
    translates :name, :description, column_suffix: '_i18n', backend: :jsonb
    default_scope { i18n }
    before_save :set_internal_data

    attr_accessor :content_template

    acts_as_paranoid

    belongs_to :external_source

    belongs_to :classification_alias_path, class_name: 'Path', primary_key: 'id', foreign_key: 'id'

    has_one :classification_tree, dependent: :destroy
    has_one :parent_classification_alias, through: :classification_tree

    has_one :classification_tree_with_deleted, -> { with_deleted }, class_name: 'ClassificationTree', foreign_key: 'classification_alias_id'
    has_one :classification_tree_label, through: :classification_tree_with_deleted

    has_one :parent_classification_alias_with_deleted, through: :classification_tree_with_deleted, source: :parent_classification_alias

    has_many :sub_classification_trees, class_name: 'ClassificationTree', foreign_key: 'parent_classification_alias_id', dependent: :destroy
    has_many :sub_classification_alias, through: :sub_classification_trees

    has_many :classification_groups, dependent: :destroy
    has_many :classifications, -> { order(:name) }, through: :classification_groups

    has_many :descendant_paths, ->(a) { unscope(:where).where('ancestor_ids @> ARRAY[?]::uuid[]', a.id) },
             class_name: 'Path'
    has_many :descendants, through: :descendant_paths, source: :classification_alias

    has_one :primary_classification_group, class_name: 'DataCycleCore::ClassificationGroup::PrimaryClassificationGroup' # rubocop:disable Rails/HasManyOrHasOneDependent
    has_one :primary_classification, through: :primary_classification_group, source: :classification
    has_many :additional_classification_groups, lambda {
      where.not(id: DataCycleCore::ClassificationGroup::PrimaryClassificationGroup.all)
    }, class_name: 'DataCycleCore::ClassificationGroup'
    has_many :additional_classifications, through: :additional_classification_groups, source: :classification

    has_one :statistics, class_name: 'Statistics', foreign_key: 'id' # rubocop:disable Rails/HasManyOrHasOneDependent

    after_update :update_primary_classification
    after_update :invalidate_things_cache, if: -> { saved_changes.keys.except(['seen_at', 'updated_at', 'assignable', 'internal', 'description_i18n']).present? || classification_groups.map(&:changed?).inject(&:|) || saved_changes&.dig('description_i18n')&.uniq&.many? }

    delegate :visible?, to: :classification_tree_label

    def self.for_tree(tree_name)
      joins(classification_tree: :classification_tree_label)
        .where('classification_trees' => { 'classification_tree_labels' => { 'name' => tree_name } })
    end

    def self.from_tree(tree_name)
      for_tree(tree_name)
    end

    def self.without_deleted
      where(deleted_at: nil)
    end

    def self.with_name(*names)
      where(name: names.flatten)
    end

    def self.with_internal_name(*names)
      where(internal_name: names.flatten)
    end

    def self.without_name(*names)
      where.not(name: names.flatten)
    end

    def self.classification_for_tree_with_name(tree_name, *names)
      for_tree(tree_name)
        .with_internal_name(names)
        .map(&:classifications)
        .flatten
        .map(&:id)
        .first
    end

    def self.classifications_for_tree_with_name(tree_name, *names)
      for_tree(tree_name)
        .with_internal_name(names)
        .map(&:classifications)
        .flatten
    end

    def self.classifications
      DataCycleCore::Classification.includes(:classification_aliases).where(classification_aliases: { id: all&.pluck(:id) })
    end

    def self.with_descendants
      query = is_a?(ActiveRecord::Relation) ? self : all

      query.unscoped
        .without_deleted
        .joins(:classification_alias_path)
        .where('full_path_ids && ARRAY[?]::uuid[]', query.pluck(:id))
    end

    def self.search(q)
      joins(:classification_alias_path).where("ARRAY_TO_STRING(full_path_names, ' | ') ILIKE :q OR (classification_aliases.description_i18n ->> :locale) ILIKE :q", { locale: I18n.locale, q: "%#{q}%" })
    end

    def self.order_by_similarity(term)
      term = ActiveRecord::Base.connection.quote(term)

      max_cardinality = Path.all.pluck(Arel.sql('MAX(CARDINALITY(full_path_names))')).max

      joins(:classification_alias_path).order(
        Arel.sql(
          (1..max_cardinality).map { |c|
            "COALESCE(10 ^ #{max_cardinality - c} * (1 - (full_path_names[#{c}] <-> #{term})), 0)"
          }.join(' + ') + ' DESC'.to_s
        )
      )
    end

    def self.in_context(context)
      all.to_a.select { |ca| (Array(ca.classification_tree_label&.visibility) & Array(context)).size.positive? }
    end

    def primary_classification_id
      primary_classification&.id
    end

    def linked_contents
      DataCycleCore::Thing.includes(:classifications).where(classifications: { id: classifications.ids }).or(DataCycleCore::Thing.includes(:classifications).where(classifications: { id: sub_classification_alias.with_descendants.classifications.ids })).distinct
    end

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 10.minutes) do
        if parent_classification_alias_with_deleted
          [parent_classification_alias_with_deleted] + parent_classification_alias_with_deleted.ancestors
        else
          [classification_tree_with_deleted.classification_tree_label_with_deleted]
        end
      end
    end

    def full_path
      classification_alias_path.full_path_names.reverse.join(' > ')
    end

    def self.with_content_templates
      templates = DataCycleCore::Thing.where(template: true)

      all.map do |c|
        c.content_template = c.find_content_template(templates)
        c
      end
    end

    def find_content_template(templates)
      template = templates.select { |t| t.schema&.dig('properties', 'data_type', 'default_value') == name }

      if template.blank? && ancestors&.first.is_a?(DataCycleCore::ClassificationAlias)
        ancestors.first.find_content_template(templates)
      elsif template.blank?
        nil
      else
        template.first
      end
    end

    def translated_locales
      @translated_locales ||= begin
        (name_i18n&.deep_reject { |_, v| v.blank? }&.symbolize_keys&.keys || []).concat(description_i18n&.deep_reject { |_, v| v.blank? }&.symbolize_keys&.keys || []).uniq
      end
    end
    alias available_locales translated_locales

    def first_available_locale(locale = nil)
      (Array(locale).map(&:to_sym).sort_by { |t| I18n.available_locales.index t }.push(I18n.locale) & translated_locales).first || translated_locales.min_by { |t| I18n.available_locales.index t }
    end

    def external_keys
      classifications.pluck(:external_key)&.join(', ')
    end

    private

    def set_internal_data
      return unless name_i18n_changed? # && internal_name.blank?
      available_translation = I18n.available_locales.drop_while { |locale| name(locale: locale).blank? }
      return if available_translation.blank?
      self.internal_name = name(locale: available_translation.first)
    end

    def update_primary_classification
      return unless saved_change_to_attribute?('internal_name')

      return if primary_classification.nil?

      primary_classification.tap do |c|
        c.name = name
        c.save!
      end
    end

    def invalidate_things_cache
      Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new(self.class.name, id, :invalidate_cache) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: self.class.name, delayed_reference_id: id, locked_at: nil)
    end

    def invalidate_cache
      linked_contents.find_each do |item|
        item&.search_languages(true)
        # TODO: move to cache warmup feature
        Rails.cache.delete_matched("*data_cycle_core/thing_#{item.id}*")
      end
    end
  end
end
