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
    after_destroy :clean_stored_filters
    before_destroy :add_things_cache_invalidation_job_destroy, :add_things_webhooks_job_destroy, -> { primary_classification&.destroy }, prepend: true
    after_update :update_primary_classification
    after_update :add_things_cache_invalidation_job_update, if: :cached_attributes_changed?
    after_update :add_things_webhooks_job_update, if: :main_attributes_changed?

    attr_accessor :content_template

    acts_as_paranoid

    belongs_to :external_source, class_name: 'DataCycleCore::ExternalSystem'

    belongs_to :classification_alias_path, class_name: 'Path', primary_key: 'id', foreign_key: 'id'

    has_one :classification_tree, dependent: :destroy
    has_one :parent_classification_alias, through: :classification_tree

    has_one :classification_tree_with_deleted, -> { with_deleted }, class_name: 'ClassificationTree', foreign_key: 'classification_alias_id'
    has_one :classification_tree_label, through: :classification_tree_with_deleted

    has_one :parent_classification_alias_with_deleted, through: :classification_tree_with_deleted, source: :parent_classification_alias

    has_many :sub_classification_trees, class_name: 'ClassificationTree', foreign_key: 'parent_classification_alias_id', dependent: :destroy
    has_many :sub_classification_alias, through: :sub_classification_trees

    has_many :classification_groups, dependent: :destroy
    has_many :classifications, -> { order(:name) }, through: :classification_groups, after_add: :classifications_changed, after_remove: :classifications_changed

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
        .primary_classifications.pluck(:id).first
    end

    def self.classifications_for_tree_with_name(tree_name, *names)
      for_tree(tree_name)
        .with_internal_name(names)
        .primary_classifications.pluck(:id)
    end

    def self.primary_classifications
      DataCycleCore::Classification.includes(:primary_classification_alias).where(classification_aliases: { id: all&.pluck(:id) })
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

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:Concept'
      }
    end

    def move_to_path(new_path, destroy_children = false)
      return if new_path.blank?

      new_path = Array.wrap(new_path)

      ctl = DataCycleCore::ClassificationTreeLabel.find_by(name: new_path.shift)

      return if ctl.nil?

      new_classification_alias = ctl.create_classification_alias(*(new_path.map { |c| { name: c } }))

      return if new_classification_alias.nil?

      ActiveRecord::Base.transaction do
        descendants.find_each do |descendant|
          if destroy_children
            descendant.merge_with(new_classification_alias)
          else
            descendant.move_to_tree(new_classification_alias, ctl.id)
          end
        end

        merge_with(new_classification_alias)
      end

      new_classification_alias.send(:invalidate_things_cache)
      new_classification_alias
    end

    def move_to_tree(parent_ca, tree_label_id)
      return if parent_ca.nil? || tree_label_id.nil?

      classification_tree&.update(parent_classification_alias_id: parent_ca.id, classification_tree_label_id: tree_label_id)
    end

    def merge_with(new_classification_alias)
      DataCycleCore::ClassificationContent.where(classification_id: primary_classification.id).find_each do |cc|
        cc.update(classification_id: new_classification_alias.primary_classification.id) unless DataCycleCore::ClassificationContent.where(classification_id: new_classification_alias.primary_classification.id, relation: cc.relation, content_data_id: cc.content_data_id).exists?
      end

      DataCycleCore::ClassificationContent::History.where(classification_id: primary_classification.id).find_each do |cc|
        cc.update(classification_id: new_classification_alias.primary_classification.id) unless DataCycleCore::ClassificationContent::History.where(classification_id: new_classification_alias.primary_classification.id, relation: cc.relation, content_data_history_id: cc.content_data_history_id).exists?
      end

      DataCycleCore::StoredFilter.update_all("parameters = replace(parameters::text, '#{id}', '#{new_classification_alias.id}')::jsonb")

      destroy
    end

    private

    def set_internal_data
      return unless name_i18n_changed? # && internal_name.blank?
      available_translation = I18n.available_locales.drop_while { |locale| name(locale: locale).blank? }
      return if available_translation.blank?
      self.internal_name = DataCycleCore::MasterData::DataConverter.string_to_string(name(locale: available_translation.first)&.to_s)
    end

    def update_primary_classification
      return unless saved_change_to_attribute?('internal_name')

      return if primary_classification.nil?

      primary_classification.tap do |c|
        c.name = DataCycleCore::MasterData::DataConverter.string_to_string(name&.to_s)
        c.save!
      end
    end

    def cached_attributes_changed?
      main_attributes_changed? || @classifications_changed
    end

    def main_attributes_changed?
      return @main_attributes_changed if defined? @main_attributes_changed

      @main_attributes_changed = (saved_changes.keys & ['internal_name', 'uri']).any? ||
                                 saved_changes.dig('name_i18n')&.map { |attr| attr.reject { |_k, v| v.blank? } }&.reject(&:blank?).present? ||
                                 saved_changes.dig('description_i18n')&.map { |attr| attr.reject { |_k, v| v.blank? } }&.reject(&:blank?).present?
    end

    def classifications_changed(_classification = nil)
      @classifications_changed = true
    end

    def add_things_webhooks_job_destroy
      return unless primary_classification&.things&.exists?

      Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationDestroyJob.new(self.class.name, id, :execute_things_webhooks_destroy, primary_classification.things.ids) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: "#{self.class.name.underscore}_execute_things_webhooks_destroy", delayed_reference_id: id)
    end

    def add_things_webhooks_job_update
      return unless primary_classification&.things&.exists?

      Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new(self.class.name, id, :execute_things_webhooks) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: "#{self.class.name.underscore}_execute_things_webhooks", delayed_reference_id: id, locked_at: nil)
    end

    def execute_things_webhooks
      primary_classification&.things&.find_each do |content|
        content.send(:execute_update_webhooks)
      end
    end

    def add_things_cache_invalidation_job_update
      Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new(self.class.name, id, :invalidate_things_cache) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: "#{self.class.name.underscore}_invalidate_things_cache", delayed_reference_id: id, locked_at: nil)
    end

    def add_things_cache_invalidation_job_destroy
      Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationDestroyJob.new(self.class.name, id, :invalidate_things_cache, primary_classification&.things&.ids) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: "#{self.class.name.underscore}_invalidate_things_cache", delayed_reference_id: id)
    end

    def invalidate_things_cache
      linked_contents.ids.each do |thing_id|
        Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new('DataCycleCore::Thing', thing_id, :invalidate_self_and_update_search) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: 'data_cycle_core/thing_invalidate_self_and_update_search', delayed_reference_id: thing_id, locked_at: nil)
      end
    end

    def clean_stored_filters
      ActiveRecord::Base.connection.execute <<-SQL
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
              stored_filters,
              jsonb_array_elements( parameters ) elem
            WHERE parameters::TEXT ILIKE '%#{id}%'
            GROUP BY id
        )
        UPDATE stored_filters
        SET
          parameters = subquery.new_parameters FROM subquery
        WHERE stored_filters.id = subquery.id
      SQL
    end
  end
end
