# frozen_string_literal: true

module DataCycleCore
  class ClassificationAlias < ApplicationRecord
    class Path < ApplicationRecord
      self.table_name = 'classification_alias_paths'

      belongs_to :classification_alias, foreign_key: :id
      belongs_to :concept, foreign_key: :id
      has_many :ancestor_classification_aliases, ->(p) { unscope(:where).where('id = ANY(ARRAY[?]::UUID[])', p.ancestor_ids) }, class_name: 'DataCycleCore::ClassificationAlias'

      def readonly?
        true
      end
    end

    extend ::Mobility
    translates :name, :description, column_suffix: '_i18n', backend: :jsonb
    default_scope { i18n }
    default_scope { order(order_a: :asc, id: :asc) }
    before_save :set_internal_data
    after_destroy :clean_stored_filters
    before_destroy :add_things_job_destroy, :add_things_webhooks_job_destroy, -> { primary_classification&.destroy }
    after_update :update_primary_classification
    after_update :add_things_cache_invalidation_job, if: :cached_attributes_changed?
    after_update :add_things_search_update_job, if: :search_attributes_changed?
    after_update :add_things_webhooks_job_update, if: :webhook_attributes_changed?

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
    accepts_nested_attributes_for :classification_polygons

    has_many :classification_alias_paths_transitive
    has_many :things, through: :primary_classification

    has_one :concept, foreign_key: :id

    delegate :visible?, to: :classification_tree_label

    scope :in_context, ->(context) { includes(:classification_tree_label).where('classification_tree_labels.visibility && ARRAY[?]::varchar[]', Array.wrap(context)).references(:classification_tree_label) }
    scope :by_full_paths, ->(full_paths) { includes(:classification_alias_path).where('classification_alias_paths.full_path_names IN (?)', Array.wrap(full_paths).map { |p| p.split('>').map(&:strip).reverse.to_pg_array }).references(:classification_alias_path) } # rubocop:disable Rails/WhereEquals

    validate :validate_color_format

    def self.for_tree(tree_name)
      return none if tree_name.blank?

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
      return if names.blank? || tree_name.blank?

      for_tree(tree_name)
        .with_internal_name(names)
        .primary_classifications.pick(:id)
    end

    def self.classifications_for_tree_with_name(tree_name, *names)
      return [] if names.blank? || tree_name.blank?

      for_tree(tree_name)
        .with_internal_name(names)
        .primary_classifications.pluck(:id)
    end

    def self.primary_classifications
      DataCycleCore::Classification.includes(:primary_classification_alias).where(classification_aliases: { id: reorder(nil).select(:id) })
    end

    def self.classifications
      DataCycleCore::Classification.includes(:classification_aliases).where(classification_aliases: { id: reorder(nil).select(:id) })
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

      max_cardinality = Path.pluck(Arel.sql('MAX(CARDINALITY(full_path_names))')).max

      joins(:classification_alias_path).reorder(nil).order(
        Arel.sql(
          (1..max_cardinality).map { |c|
            "COALESCE(10 ^ #{max_cardinality - c} * (1 - (full_path_names[#{c}] <-> #{term})), 0)"
          }.join(' + ') + ' DESC'.to_s
        )
      )
    end

    def self.classification_polygons
      return DataCycleCore::ClassificationPolygon.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::ClassificationPolygon.where(classification_alias_id: select(:id))
    end

    def primary_classification_id
      primary_classification&.id
    end

    def linked_contents
      DataCycleCore::Thing.includes(:classifications).where(classifications: { id: classifications.pluck(:id) }).or(DataCycleCore::Thing.includes(:classifications).where(classifications: { id: sub_classification_alias.with_descendants.classifications.pluck(:id) })).distinct
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
      includes(:classification_alias_path)
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

      classification_groups.insert({ classification_id: mapped_ca.primary_classification.id, updated_at: Time.zone.now }, unique_by: :classification_groups_ca_id_c_id_uq_idx).count
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

      transaction do
        if new_ca.nil?
          new_parent = ctl.create_classification_alias(*(new_path[1...-1].map { |c| { name: c } }))

          merge_children_into_self if destroy_children
          move_to_tree(new_parent&.id, ctl.id)
          new_ca = self
        else
          merge_with_children(new_ca, destroy_children)
        end
      end

      new_ca
    end

    def move_after(tree_label, previous_sibling, parent_ca = nil)
      parent_ca = previous_sibling&.parent_classification_alias if parent_ca.nil?

      move_to_tree(parent_ca&.id, tree_label.id)
      update_columns(updated_at: Time.zone.now, order_a: previous_sibling&.reload&.order_a || parent_ca&.reload&.order_a || 0)
    end

    def move_to_tree(parent_ca_id, tree_label_id)
      return if tree_label_id.nil?

      classification_tree&.update(parent_classification_alias_id: parent_ca_id, classification_tree_label_id: tree_label_id)

      return unless classification_tree&.changed?

      add_things_cache_invalidation_job
      add_things_search_update_job
      add_things_webhooks_job_update
    end

    def merge_children_into_self
      descendants.find_each do |d|
        d.prevent_webhooks = prevent_webhooks
        d.merge_with(self)
      end
    end

    def merge_with_children(new_classification_alias, destroy_children = false)
      transaction do
        if destroy_children
          merge_children_into_self
        else
          sub_classification_trees.update_all(parent_classification_alias_id: new_classification_alias.id, classification_tree_label_id: new_classification_alias.classification_tree_label.id)
        end

        merge_with(new_classification_alias)
      end
    end

    def merge_with(new_classification_alias)
      # update Mappings
      additional_classification_groups.where.not('EXISTS (SELECT 1 FROM classification_groups cg WHERE cg.classification_id = classification_groups.classification_id AND cg.classification_alias_id = ?)', new_classification_alias.id).update_all(classification_alias_id: new_classification_alias.id, created_at: Time.zone.now, updated_at: Time.zone.now)

      primary_classification.additional_classification_groups.where.not('EXISTS (SELECT 1 FROM classification_groups cg WHERE cg.classification_alias_id = classification_groups.classification_alias_id AND cg.classification_id = ?)', new_classification_alias.primary_classification.id).update_all(classification_id: new_classification_alias.primary_classification.id, created_at: Time.zone.now, updated_at: Time.zone.now)

      # update classification_contents
      primary_classification.classification_contents.where.not('EXISTS (SELECT 1 FROM classification_contents cc WHERE cc.content_data_id = classification_contents.content_data_id AND cc.relation = classification_contents.relation AND cc.classification_id = ?)', new_classification_alias.primary_classification.id).update_all(classification_id: new_classification_alias.primary_classification.id)

      primary_classification.classification_content_histories.where.not('EXISTS (SELECT 1 FROM classification_content_histories cc WHERE cc.content_data_history_id = classification_content_histories.content_data_history_id AND cc.relation = classification_content_histories.relation AND cc.classification_id = ?)', new_classification_alias.primary_classification.id).update_all(classification_id: new_classification_alias.primary_classification.id)

      # update classification_polygons
      classification_polygons.update_all(classification_alias_id: new_classification_alias.id)

      # update classification_user_groups
      primary_classification.classification_user_groups.where.not('EXISTS (SELECT 1 FROM classification_user_groups cg WHERE cg.user_group_id = classification_user_groups.user_group_id AND cg.classification_id = ?)', new_classification_alias.primary_classification.id).update_all(classification_id: new_classification_alias.primary_classification.id)

      # update stored_filters
      DataCycleCore::StoredFilter
        .where(id: DataCycleCore::StoredFilter.where('parameters::TEXT ILIKE ?', "%#{id}%").lock('FOR UPDATE SKIP LOCKED').order(:id).select(:id))
        .update_all("parameters = replace(parameters::text, '#{id}', '#{new_classification_alias.id}')::jsonb")

      destroy

      new_classification_alias.send(:add_things_cache_invalidation_job)
      new_classification_alias.send(:add_things_search_update_job)
      new_classification_alias.send(:add_things_webhooks_job_update)
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_source&.identifier })
        .merge(attributes)
        .merge({ 'primary_classification' => primary_classification.to_hash })
    end

    def color
      ui_configs&.dig('color')
    end

    def color?
      color.present?
    end

    def icon
      icon = DataCycleCore.classification_icons[id] || DataCycleCore.classification_icons[classification_tree_label&.id]

      return if icon.blank?

      DataCycleCore::LocalizationService.view_helpers.dc_image_url("icons/#{icon}")
    end

    def icon?
      icon.present?
    end

    private

    def validate_color_format
      return unless color?

      errors.add(:ui_configs, :color_format) unless /^#((?:\h{1,2}){3,4})$/i.match?(color)
    end

    def set_internal_data
      return unless name_i18n_changed? # && internal_name.blank?
      available_translation = I18n.available_locales.drop_while { |locale| name(locale:).blank? }
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

    def search_attributes_changed?
      return @search_attributes_changed if defined? @search_attributes_changed

      @search_attributes_changed = saved_changes.keys.intersect?(['internal_name']) ||
                                   saved_changes.dig('name_i18n')&.map { |attr| attr.reject { |_k, v| v.blank? } }&.reject(&:blank?).present?
    end

    def cached_attributes_changed?
      webhook_attributes_changed? || @classifications_changed || saved_changes.dig('ui_configs')&.map { |attr| attr&.reject { |_k, v| v.blank? } }&.reject(&:blank?).present?
    end

    def webhook_attributes_changed?
      return @webhook_attributes_changed if defined? @webhook_attributes_changed

      @webhook_attributes_changed = saved_changes.keys.intersect?(['internal_name', 'uri']) ||
                                    saved_changes.dig('name_i18n')&.map { |attr| attr.reject { |_k, v| v.blank? } }&.reject(&:blank?).present? ||
                                    saved_changes.dig('description_i18n')&.map { |attr| attr.reject { |_k, v| v.blank? } }&.reject(&:blank?).present?
    end

    def classifications_added(_classification = nil)
      @classifications_changed = true
    end

    def classifications_removed(classification = nil)
      unless classification.nil?
        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'invalidate_things_cache', classification.things.ids)
        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', classification.things.ids) if classification_tree_label&.change_behaviour&.include?('trigger_webhooks')
      end

      @classifications_changed = true
    end

    def add_things_webhooks_job_destroy
      return unless classification_tree_label&.change_behaviour&.include?('trigger_webhooks') && classifications.things.exists?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', classifications.things.ids)
    end

    def add_things_webhooks_job_update
      return if prevent_webhooks
      return unless classification_tree_label&.change_behaviour&.include?('trigger_webhooks') && classifications.things.exists?

      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'execute_things_webhooks')
    end

    def execute_things_webhooks
      linked_contents.find_each do |content|
        content.send(:execute_update_webhooks) unless content.embedded?
      end
    end

    def add_things_cache_invalidation_job
      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'invalidate_things_cache')
    end

    def add_things_search_update_job
      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'update_things_search')
    end

    def add_things_job_destroy
      return unless classifications.things.exists?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(
        self.class.name,
        id,
        'invalidate_things_cache',
        classifications.things.ids
      )
    end

    def invalidate_things_cache
      linked_contents.invalidate_all
    end

    def update_things_search
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
              collections ,
              jsonb_array_elements( parameters ) elem
            WHERE parameters::TEXT ILIKE '%#{id}%'
            GROUP BY id
        )
        UPDATE collections
        SET
          parameters = subquery.new_parameters FROM subquery
        WHERE collections.id = subquery.id
      SQL
    end
  end
end
