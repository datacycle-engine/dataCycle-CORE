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

    extend ::Translations
    translates :name, :description, column_suffix: '_i18n', backend: :jsonb
    default_scope { i18n }
    before_save :set_internal_data
    after_destroy :clean_stored_filters
    before_destroy :add_things_cache_invalidation_job_destroy, :add_things_webhooks_job_destroy, -> { primary_classification&.destroy }
    after_update :update_primary_classification
    after_update :add_things_cache_invalidation_job_update, if: :cached_attributes_changed?
    after_update :add_things_webhooks_job_update, if: :main_attributes_changed?

    attr_accessor :content_template, :prevent_webhooks

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
    has_many :classifications, -> { order(:name) }, through: :classification_groups, after_add: :classifications_added, after_remove: :classifications_removed

    has_many :descendant_paths, ->(a) { unscope(:where).where('ancestor_ids @> ARRAY[?]::uuid[]', a.id) },
             class_name: 'Path'
    has_many :descendants, through: :descendant_paths, source: :classification_alias

    has_one :primary_classification_group, class_name: 'DataCycleCore::ClassificationGroup::PrimaryClassificationGroup' # rubocop:disable Rails/HasManyOrHasOneDependent
    has_one :primary_classification, through: :primary_classification_group, source: :classification
    has_many :additional_classification_groups, lambda {
      where.not(id: DataCycleCore::ClassificationGroup::PrimaryClassificationGroup.all)
    }, class_name: 'DataCycleCore::ClassificationGroup'
    has_many :additional_classifications, through: :additional_classification_groups, source: :classification

    has_many :classification_polygons, dependent: :destroy
    has_many :classification_alias_paths_transitive

    delegate :visible?, to: :classification_tree_label

    def self.for_tree(tree_name)
      joins(classification_tree: :classification_tree_label)
        .where(classification_trees: { classification_tree_labels: { name: tree_name } })
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
        .primary_classifications.pick(:id)
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
      joins(:classification_alias_path).where("ARRAY_TO_STRING(full_path_names, ' | ') ILIKE :q OR (classification_aliases.description_i18n ->> :locale) ILIKE :q OR (classification_aliases.name_i18n ->> :locale) ILIKE :q", { locale: I18n.locale, q: "%#{q}%" })
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
      all.includes(:classification_tree_label).where('classification_tree_labels.visibility && ARRAY[?]::varchar[]', Array.wrap(context)).references(:classification_tree_label)
    end

    def primary_classification_id
      primary_classification&.id
    end

    def linked_contents
      DataCycleCore::Thing.includes(:classifications).where(classifications: { id: classifications.ids }).or(DataCycleCore::Thing.includes(:classifications).where(classifications: { id: sub_classification_alias.with_descendants.classifications.ids })).distinct
    end

    def ancestors
      Rails.cache.fetch("#{cache_key}/ancestors", expires_in: 10.minutes, race_condition_ttl: 60.seconds) do
        if parent_classification_alias_with_deleted
          [parent_classification_alias_with_deleted] + parent_classification_alias_with_deleted.ancestors
        else
          [classification_tree_with_deleted.classification_tree_label_with_deleted]
        end
      end
    end

    def full_path
      classification_alias_path&.full_path_names&.reverse&.join(' > ')
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
      @translated_locales ||= (name_i18n&.deep_reject { |_, v| v.blank? }&.symbolize_keys&.keys || []).concat(description_i18n&.deep_reject { |_, v| v.blank? }&.symbolize_keys&.keys || []).uniq
    end
    alias available_locales translated_locales

    def first_available_locale(locale = nil)
      (Array(locale).map(&:to_sym).sort_by { |t| I18n.available_locales.index t }.push(I18n.locale) & translated_locales).first || translated_locales.min_by { |t| I18n.available_locales.index t }
    end

    def external_keys
      classifications.pluck(:external_key)&.compact&.join(', ')
    end

    def mapped_to_string
      primary_classification&.additional_classification_aliases&.map(&:name)&.join(',')
    end

    def mapped_to
      primary_classification&.additional_classification_aliases
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:Concept'
      }
    end

    def self.custom_find_by_full_path(full_path)
      all.includes(:classification_alias_path)
      .where(
        "array_to_string(classification_alias_paths.full_path_names, ' < ') ILIKE ?",
        full_path.split('>').reverse.map(&:strip).join(' < ')
      )
      .references(:classification_alias_paths)
      .first
    end

    def self.custom_find_by_full_path!(full_path)
      custom_find_by_full_path(full_path) || raise(ActiveRecord::RecordNotFound)
    end

    def create_mapping_for_path(full_path)
      mapped_ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path!(full_path)

      raise ActiveRecord::RecordNotFound if mapped_ca.primary_classification.nil?

      self.classification_ids += [mapped_ca.primary_classification.id] unless mapped_ca.primary_classification.id.in?(classification_ids)
    end

    def move_to_path(new_path, destroy_children = false)
      return if new_path.blank?

      new_path = Array.wrap(new_path)

      if new_path.first.uuid?
        new_ca = DataCycleCore::ClassificationAlias.find_by(id: new_path.first)
        ctl = new_ca&.classification_tree_label
      else
        ctl = DataCycleCore::ClassificationTreeLabel.find_by(name: new_path.first)

        new_ca = DataCycleCore::ClassificationAlias.includes(:classification_alias_path).find_by(classification_alias_paths: { full_path_names: new_path.reverse })
      end

      return if ctl.nil?

      ActiveRecord::Base.transaction do
        if new_ca.nil?
          new_parent = ctl.create_classification_alias(*(new_path[1...-1].map { |c| { name: c } }))

          if destroy_children
            descendants.find_each do |d|
              d.prevent_webhooks = prevent_webhooks
              d.merge_with(self)
            end
          end

          move_to_tree(new_parent, ctl.id)
          new_ca = self
        else
          if destroy_children
            descendants.find_each do |d|
              d.prevent_webhooks = prevent_webhooks
              d.merge_with(new_ca)
            end
          else
            descendants.find_each do |d|
              d.prevent_webhooks = prevent_webhooks
              d.move_to_tree(new_ca, ctl.id)
            end
          end

          merge_with(new_ca)
        end
      end

      new_ca
    end

    def move_to_tree(parent_ca, tree_label_id)
      return if tree_label_id.nil?

      classification_tree&.update(parent_classification_alias_id: parent_ca&.id, classification_tree_label_id: tree_label_id)

      add_things_cache_invalidation_job_update
      add_things_webhooks_job_update unless prevent_webhooks
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

      new_classification_alias.send(:add_things_cache_invalidation_job_update)
      new_classification_alias.send(:add_things_webhooks_job_update) unless prevent_webhooks
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_source&.identifier })
        .merge(attributes)
        .merge({ 'primary_classification' => primary_classification.to_hash })
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

    def classifications_added(_classification = nil)
      @classifications_changed = true
    end

    def classifications_removed(classification = nil)
      unless classification.nil?
        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'invalidate_things_cache', classification.things.ids) if classification_tree_label&.change_behaviour&.include?('clear_cache')
        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', classification.things.ids) if classification_tree_label&.change_behaviour&.include?('trigger_webhooks')
      end

      @classifications_changed = true
    end

    def add_things_webhooks_job_destroy
      return unless classification_tree_label&.change_behaviour&.include?('trigger_webhooks') && classifications.things.exists?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', classifications.things.ids)
    end

    def add_things_webhooks_job_update
      return unless classification_tree_label&.change_behaviour&.include?('trigger_webhooks') && classifications.things.exists?

      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'execute_things_webhooks')
    end

    def execute_things_webhooks
      classifications.things.find_each do |content|
        content.send(:execute_update_webhooks)
      end
    end

    def add_things_cache_invalidation_job_update
      return unless classification_tree_label&.change_behaviour&.include?('clear_cache')

      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'invalidate_things_cache')
    end

    def add_things_cache_invalidation_job_destroy
      return unless classification_tree_label&.change_behaviour&.include?('clear_cache') && classifications.things.exists?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'invalidate_things_cache', classifications.things.ids)
    end

    def invalidate_things_cache
      linked_contents.invalidate_all
      linked_contents.update_search_all
    end

    def clean_stored_filters
      ActiveRecord::Base.connection.execute <<-SQL.squish
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
