# frozen_string_literal: true

module DataCycleCore
  class ClassificationAlias < ApplicationRecord
    class Path < ApplicationRecord
      self.table_name = 'classification_alias_paths'

      belongs_to :classification_alias, foreign_key: :id
      belongs_to :concept, foreign_key: :id
      has_many :ancestor_classification_aliases, ->(p) { unscope(:where).where('id = ANY(ARRAY[?]::UUID[])', p.ancestor_ids).by_ordered_values(p.ancestor_ids) }, class_name: 'DataCycleCore::ClassificationAlias'
      has_many :ancestor_concepts, ->(p) { unscope(:where).where('id = ANY(ARRAY[?]::UUID[])', p.ancestor_ids).by_ordered_values(p.ancestor_ids) }, class_name: 'DataCycleCore::Concept'

      def readonly?
        true
      end
    end

    extend ::Mobility

    validates :internal_name, presence: true
    validate :validate_color_format

    translates :name, :description, column_suffix: '_i18n', backend: :jsonb
    default_scope { i18n }
    default_scope { order(order_a: :asc, id: :asc) }
    before_validation :set_internal_data
    after_update :update_primary_classification
    after_update :add_things_cache_invalidation_job, if: :cached_attributes_changed?
    after_update :add_things_search_update_job, if: :search_attributes_changed?
    after_update :add_linked_things_computed_properties_job, if: :search_attributes_changed?
    after_update :add_things_webhooks_job_update, if: :webhook_attributes_changed?
    before_destroy :add_things_job_destroy, :add_things_webhooks_job_destroy, :destroy_primary_classification
    after_destroy :clean_stored_filters
    after_find :set_thing_counts

    attr_accessor :content_template, :prevent_webhooks, :thing_count_with_subtree, :thing_count_without_subtree

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

    has_one :concept, foreign_key: :id
    has_one :primary_classification, through: :concept, source: :classification, class_name: 'Classification'
    has_many :additional_classification_groups, through: :concept, source: :mapped_classification_groups, class_name: 'ClassificationGroup'
    has_many :additional_classifications, through: :concept, source: :mapped_classifications, class_name: 'Classification'
    has_many :collected_classification_contents # , through: :collected_classification_content

    has_many :classification_polygons, dependent: :destroy
    accepts_nested_attributes_for :classification_polygons

    has_many :classification_alias_paths_transitive
    has_many :things, through: :primary_classification

    delegate :visible?, to: :classification_tree_label

    scope :in_context, ->(context) { includes(:classification_tree_label).where('classification_tree_labels.visibility && ARRAY[?]::varchar[]', Array.wrap(context)).references(:classification_tree_label) }
    scope :by_full_paths, ->(full_paths) { includes(:classification_alias_path).where('classification_alias_paths.full_path_names IN (?)', Array.wrap(full_paths).map { |p| p.split('>').map(&:strip).reverse.to_pg_array }).references(:classification_alias_path) } # rubocop:disable Rails/WhereEquals
    scope :assignable, -> { where(assignable: true) }
    scope :visible, ->(context) { joins(:classification_tree_label).merge(ClassificationTreeLabel.visible(context)) }
    scope :with_locale, lambda { |locales|
      Array.wrap(locales)
        .map { |l| where("classification_aliases.name_i18n ->> '#{l}' IS NOT NULL AND classification_aliases.name_i18n ->> '#{l}' != ''") }
        .inject { |scope, query| scope.or(query) }
    }

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
      DataCycleCore::Classification.includes(:primary_classification_alias)
        .where(classification_aliases: { id: reorder(nil).pluck(:id) })
    end

    def self.classifications
      DataCycleCore::Classification.includes(:classification_aliases)
        .where(classification_aliases: { id: reorder(nil).pluck(:id) })
    end

    def self.with_descendants
      query = is_a?(ActiveRecord::Relation) ? self : all

      query.unscoped
        .without_deleted
        .joins(:classification_alias_path)
        .where('full_path_ids && ARRAY[?]::uuid[]', query.pluck(:id))
    end

    def self.search(q)
      joins(:classification_alias_path).where("ARRAY_TO_STRING(ARRAY_REVERSE(full_path_names), ' > ') ILIKE :q OR (classification_aliases.description_i18n ->> :locale) ILIKE :q OR (classification_aliases.name_i18n ->> :locale) ILIKE :q", { locale: I18n.locale, q: "%#{q.squish.gsub(/\s/, '%')}%" })
    end

    def self.order_by_similarity(term)
      term = ActiveRecord::Base.connection.quote(term)

      max_cardinality = Path.pluck(Arel.sql('MAX(CARDINALITY(full_path_names))')).max
      order_string = (1..max_cardinality).map { |c| "COALESCE(10 ^ #{max_cardinality - c} * (1 - (full_path_names[#{c}] <-> :term)), 0)" }.join(' + ')
      order_string += ' DESC'

      joins(:classification_alias_path).reorder(nil).order(
        Arel.sql(
          ActiveRecord::Base.send(
            :sanitize_sql_array,
            [
              order_string,
              { term: }
            ]
          )
        )
      )
    end

    def self.classification_polygons
      DataCycleCore::ClassificationPolygon.where(classification_alias_id: pluck(:id))
    end

    def primary_classification_id
      primary_classification&.id
    end

    def linked_contents
      DataCycleCore::Thing.where(
        collected_classification_contents
          .without_hidden # #47172: hidden mappings do not link a content to this classification
          .select(1)
          .where('collected_classification_contents.thing_id = things.id')
          .arel
          .exists
      )
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
      (Array(locale).map(&:to_sym).sort_by { |t| locale_priority(t) }.push(I18n.locale) & translated_locales).first || translated_locales.min_by { |t| locale_priority(t) }
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
          "ARRAY_TO_STRING(ARRAY_REVERSE(full_path_names), ' > ') ILIKE ?",
          full_path
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
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

        if new_ca.nil?
          new_parent = ctl.create_classification_alias(*new_path[1...-1].map { |c| { name: c } })

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

      transaction do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
        move_to_tree(parent_ca&.id, tree_label.id)
        update_columns(updated_at: Time.zone.now, order_a: previous_sibling&.reload&.order_a || parent_ca&.reload&.order_a || 0)
      end
    end

    def move_to_tree(parent_ca_id, tree_label_id)
      return if tree_label_id.nil?

      classification_tree&.update(parent_classification_alias_id: parent_ca_id, classification_tree_label_id: tree_label_id)

      return unless classification_tree&.saved_changes?

      add_things_cache_invalidation_job
      add_things_search_update_job
      add_things_webhooks_job_update
      # no callback covers a move: the write lands on classification_trees, and move_after bypasses it
      # with update_columns. Reloaded because the line above can memoize the tree from before the move.
      add_linked_things_computed_properties_job(reload_classification_tree_label&.name)
    end

    def merge_children_into_self
      descendants.find_each do |d|
        d.prevent_webhooks = prevent_webhooks
        d.merge_with(self)
      end
    end

    def merge_with_children(new_classification_alias, destroy_children = false)
      transaction do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

        if destroy_children
          merge_children_into_self
        else
          sub_classification_trees.update_all(parent_classification_alias_id: new_classification_alias.id, classification_tree_label_id: new_classification_alias.classification_tree_label.id)
        end

        merge_with(new_classification_alias)
      end
    end

    def merge_with(new_classification_alias)
      ensure_external_system_mergeable!(new_classification_alias)

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

      # after destroy: our (external_source_id, external_key) is free again, so the target can take it
      # over without tripping the partial unique index on live rows
      move_external_system_to(new_classification_alias)

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
      icon = DataCycleCore.classification_icons[id] ||
             DataCycleCore.classification_icons[classification_tree_label&.id] ||
             DataCycleCore.classification_icons[external_key] ||
             DataCycleCore.classification_icons[full_path]

      return if icon.blank?

      DataCycleCore::LocalizationService.view_helpers.dc_image_url("icons/#{icon}")
    end

    def icon?
      icon.present?
    end

    private

    def set_thing_counts
      self.thing_count_with_subtree = self['thing_count_with_subtree']
      self.thing_count_without_subtree = self['thing_count_without_subtree']
    end

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

    # Redmine #51232: a merge that destroys the system-owned side loses its external key, and the
    # importer's ON CONFLICT only sees live rows -- so the next run recreates the concept instead of
    # updating the target, and the duplicate is back. Refused when both sides carry an external
    # identity, because the target has room for exactly one.
    # The identity an import matches on is the (external_source_id, external_key) pair, and both
    # unique indexes are NULLS NOT DISTINCT -- so a bare key is an identity too. A config concept's
    # is exactly (NULL, full_path): ConceptImporter#insert_concepts looks it up on that pair.
    def ensure_external_system_mergeable!(new_classification_alias)
      return if external_source_id.nil?
      return if new_classification_alias.external_source_id.nil? && new_classification_alias.external_key.nil?
      # only reachable with a NULL key on both sides: index_classification_aliases_unique_external_source_id_and_key
      # is NULLS NOT DISTINCT but partial on external_key IS NOT NULL, so two live aliases cannot share
      # a real key. Nothing to refuse there -- neither side carries an identity an import could match on.
      return if [external_source_id, external_key] == [new_classification_alias.external_source_id, new_classification_alias.external_key]

      raise DataCycleCore::Error::AmbiguousClassificationExternalSystemError.new(self, new_classification_alias)
    end

    # Hands our external identity to the target so the next import updates it instead of inserting a
    # new concept. The alias write propagates to concepts via update_concepts_trigger; the
    # classification needs its own, because the importer matches classifications on the same pair.
    def move_external_system_to(new_classification_alias)
      return if external_source_id.nil?
      return if new_classification_alias.external_source_id.present?

      release_external_system_from_primary_classification

      new_classification_alias.update_columns(external_source_id:, external_key:, updated_at: Time.zone.now)
      new_classification_alias.primary_classification&.update_columns(external_source_id:, external_key:, updated_at: Time.zone.now)
    end

    # destroy_primary_classification leaves our classification alive whenever another concept still
    # claims it, and it keeps carrying our pair --
    # index_classifications_unique_external_source_id_and_key is partial on live rows, so handing the
    # pair to the target would raise. The pair belongs to the alias we just destroyed, never to the
    # concept that kept the classification, so releasing it here loses nothing.
    # Only for a key the index actually covers: with a NULL key there is nothing to collide with and
    # nothing an import could match on either.
    def release_external_system_from_primary_classification
      return if external_key.nil?

      DataCycleCore::Classification
        .where(id: primary_classification&.id, external_source_id:, external_key:)
        .update_all(external_source_id: nil, external_key: nil, updated_at: Time.zone.now)
    end

    # Redmine #51232: primary_classification reads the trigger-maintained concepts.classification_id,
    # which a second live concept can also claim -- upsert_concept_tables_trigger_function promotes a
    # mapping to primary whenever the inserting alias has no live group of its own.
    # Destroying that classification takes the co-owner's data down too: classification_contents are
    # hard-deleted, and its own classification_group is soft-deleted with the rest.
    # Skipping is enough to leave a clean state -- has_many :classification_groups, dependent: :destroy
    # still detaches our own groups.
    def destroy_primary_classification
      return if primary_classification.nil?
      return if DataCycleCore::Concept.where(classification_id: primary_classification.id).where.not(id:).exists?

      primary_classification.destroy
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

      @search_attributes_changed = saved_changes.key?('internal_name') ||
                                   saved_changes['name_i18n']&.map(&:compact_blank)&.reject(&:blank?).present?
    end

    def cached_attributes_changed?
      webhook_attributes_changed? || @classifications_changed || saved_changes['ui_configs']&.map { |attr| attr&.reject { |_k, v| v.blank? } }&.reject(&:blank?).present?
    end

    def webhook_attributes_changed?
      return @webhook_attributes_changed if defined? @webhook_attributes_changed

      @webhook_attributes_changed = saved_changes.keys.intersect?(['internal_name', 'uri']) ||
                                    saved_changes['name_i18n']&.map(&:compact_blank)&.reject(&:blank?).present? ||
                                    saved_changes['description_i18n']&.map(&:compact_blank)&.reject(&:blank?).present?
    end

    # after_add/after_remove association callbacks — fire once per classification. For a bulk
    # mapping delta (ClassificationMappingJob / the dc:classifications rake) call
    # #classifications_changed instead: looping these would run a pluck + enqueue per
    # classification and, because CacheInvalidationDestroyJob dedups on (alias, method) without
    # thing_ids, collapse every side effect down to the last classification's contents.
    def classifications_added(classification = nil)
      enqueue_thing_cache_jobs(classification&.things&.pluck(:id))
      @classifications_changed = true
    end

    def classifications_removed(classification = nil)
      enqueue_thing_cache_jobs(classification&.things&.pluck(:id))
      @classifications_changed = true
    end

    # Bulk sibling of classifications_added/classifications_removed for a mapping delta that
    # touches many classifications at once. Computes the union of affected contents in one
    # query and enqueues ONE job per side effect (search, webhooks, computed-property
    # recompute), sidestepping the per-classification dedup collapse and N+1 churn above.
    def classifications_changed(classification_ids)
      return if classification_ids.blank?

      @classifications_changed = true

      thing_ids = DataCycleCore::Thing.joins(:classifications).where(classifications: { id: classification_ids }).distinct.pluck(:id)
      enqueue_thing_cache_jobs(thing_ids)
      add_things_computed_properties_job(thing_ids)
    end

    # Enqueues a single recompute for the union of affected contents. Separate from
    # enqueue_thing_cache_jobs because the per-classification callbacks intentionally skip the
    # (expensive) recompute — it runs once for the whole delta via #classifications_changed.
    def add_things_computed_properties_job(thing_ids)
      return if thing_ids.blank?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'update_things_computed_properties', thing_ids)
    end

    # A rename or a move writes no content, so nothing else recomputes a value derived from this concept.
    # The stale contents are linked_contents, not the directly assigned things a mapping delta uses:
    # parent_classification_name stores the *parent's* name, so they hang below the changed concept.
    # Resolved in the job — tens of thousands of ids are too many to travel as job arguments.
    #
    # Gated here so a tree with no opted-in property, or a concept with no linked content, enqueues nothing.
    #
    # Accepted: linked_contents is transitive, so a whole-tree relabel recomputes a content per ancestor.
    #
    # A cross-tree move only covers the new tree — the job re-reads the tree label at perform time.
    def add_linked_things_computed_properties_job(tree_label = classification_tree_label&.name)
      return if tree_label.blank?
      return if DataCycleCore::ThingTemplate.classification_change_computed_properties_for(tree_label).blank?
      return unless linked_contents.exists?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'update_linked_things_computed_properties', nil)
    end

    def enqueue_thing_cache_jobs(thing_ids)
      return if thing_ids.blank?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'update_things_search', thing_ids)
      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', thing_ids) if classification_tree_label&.trigger_webhooks?
    end

    def add_things_webhooks_job_destroy
      return unless classification_tree_label&.trigger_webhooks? && classifications.things.exists?

      DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', classifications.things.pluck(:id))
    end

    def add_things_webhooks_job_update
      return if prevent_webhooks
      return unless classification_tree_label&.trigger_webhooks? && classifications.things.exists?

      DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'execute_things_webhooks')
    end

    # Invalidated through the fan-out like the tree label path: #invalidate_things_cache covers the
    # same set, but runs in a CacheInvalidationJob under a concurrency key of its own, so nothing
    # orders it against this one.
    def execute_things_webhooks
      DataCycleCore::Content::RelatedWebhooks.fan_out(linked_contents, invalidate_related_cache: true)
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
        'update_things_search',
        classifications.things.pluck(:id)
      )
    end

    # invalidate all linked things (direct and mapped) and their related things
    # ignore locked records to avoid deadlocks, as those are already invalidated by their transactions
    def invalidate_things_cache
      linked_contents
        .except(:includes)
        .lock('FOR UPDATE SKIP LOCKED')
        .with_cached_related_contents
        .invalidate_all
    end

    def update_things_search
      linked_contents.update_search_all
    end

    def clean_stored_filters
      ActiveRecord::Base.connection.exec_query <<~SQL.squish
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
