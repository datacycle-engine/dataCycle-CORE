# frozen_string_literal: true

module DataCycleCore
  class Concept < ApplicationRecord
    # Redmine #41458: `concepts` carries no deleted_at, so a deleted concept is moved here by
    # delete_concepts_to_histories_trigger - this is what `with_deleted` / `only_deleted` used to
    # answer. Read-only: the trigger is the only writer.
    class History < ApplicationRecord
      include ConceptExtensions::Presentable

      belongs_to :external_system, optional: true
      belongs_to :concept_scheme, optional: true

      # concept_paths and concept_polygons go with the concept through their FK ON DELETE CASCADE, so
      # a deleted concept has no ancestry and an empty geometry association. concept_scheme_id is a
      # plain column and survives, which is why #ancestors_with_concept_scheme still answers.
      has_many :concept_polygons, foreign_key: :concept_id, inverse_of: false

      # Concept#search matches the full path as well; concept_paths is gone here, so this matches the
      # name and description the history row kept.
      scope :search, ->(q) { where('(concept_histories.name_i18n ->> :locale) ILIKE :q OR (concept_histories.description_i18n ->> :locale) ILIKE :q', { locale: I18n.locale, q: "%#{q.squish.gsub(/\s/, '%')}%" }) }
      scope :order_by_similarity, ->(term) { reorder(nil).order([Arel.sql('similarity(concept_histories.internal_name, ?) DESC'), term]) }

      def ancestors
        []
      end

      def full_path
        nil
      end

      def readonly?
        true
      end
    end

    include ConceptExtensions::Presentable
    include ConceptExtensions::Pathable
    include ConceptExtensions::Mergeable
    include ConceptExtensions::CacheInvalidation

    default_scope { i18n.order(order_a: :asc, id: :asc) }

    validates :internal_name, presence: true
    validate :validate_color_format

    before_validation :set_internal_name
    after_create :create_parent_link
    after_find :set_thing_counts

    # +parent_concept+ is write-only and consumed by #create_parent_link; read the parent back
    # through the association.
    attr_accessor :content_template, :parent_concept, :prevent_webhooks, :thing_count_with_subtree, :thing_count_without_subtree

    belongs_to :external_system
    belongs_to :concept_scheme

    # The link rows themselves are removed by the FK ON DELETE CASCADE on both parent_id and
    # child_id; only the child *concepts* need destroying, the way the legacy classification_trees
    # chain took a subtree down with its root.
    has_one :parent_concept_link, -> { broader }, inverse_of: :child, class_name: 'ConceptLink', foreign_key: :child_id
    has_one :parent, through: :parent_concept_link

    has_many :children_concept_links, -> { broader }, inverse_of: :parent, class_name: 'ConceptLink', foreign_key: :parent_id
    has_many :children, through: :children_concept_links, dependent: :destroy

    has_many :mapped_concept_links, -> { related }, inverse_of: :parent, class_name: 'ConceptLink', foreign_key: :parent_id
    has_many :mapped_concepts, through: :mapped_concept_links, source: :child, after_add: :mapped_concepts_added, after_remove: :mapped_concepts_removed

    has_many :mapped_inverse_concept_links, -> { related }, inverse_of: :child, class_name: 'ConceptLink', foreign_key: :child_id
    has_many :mapped_inverse_concepts, through: :mapped_inverse_concept_links, source: :parent

    has_many :concept_polygons, dependent: :destroy
    accepts_nested_attributes_for :concept_polygons

    has_many :concept_contents, dependent: :delete_all
    has_many :things, through: :concept_contents, source: :content_data
    has_many :concept_content_histories, class_name: 'DataCycleCore::ConceptContent::History'
    has_many :thing_histories, through: :concept_content_histories, source: :content_data_history

    has_many :collected_concept_contents

    has_many :concept_user_groups, dependent: :destroy
    has_many :user_groups, through: :concept_user_groups

    scope :in_context, ->(context) { includes(:concept_scheme).where('concept_schemes.visibility && ARRAY[?]::varchar[]', Array.wrap(context)).references(:concept_scheme) }
    scope :visible, ->(context) { joins(:concept_scheme).merge(ConceptScheme.visible(context)) }
    scope :assignable, -> { where(assignable: true) }
    # Scheme membership lives on concepts.concept_scheme_id and says nothing about depth; a root is
    # a concept whose `broader` link carries no parent (see DataCycleCore::ConceptLink).
    scope :roots, -> { joins(:parent_concept_link).where(concept_links: { parent_id: nil }) }

    scope :for_tree, ->(scheme_name) { scheme_name.blank? ? none : includes(:concept_scheme).where(concept_schemes: { name: scheme_name }) }
    scope :from_tree, ->(scheme_name) { for_tree(scheme_name) }
    scope :with_name, ->(*names) { where(name: names.flatten) }
    scope :with_internal_name, ->(*names) { where(internal_name: names.flatten) }
    scope :with_external_key, ->(*external_keys) { where(external_key: external_keys.flatten) }
    scope :without_name, ->(*names) { where.not(name: names.flatten) }
    scope :by_external_systems_and_keys, -> { _1.blank? ? none : where(Array.new(_1.size) { '(external_system_id = ? AND external_key = ?)' }.join(' OR '), *_1.pluck(:external_system_id, :external_key).flatten) }

    # The concept a scheme names by an internal name - the entry point for every config and computed
    # property that identifies a concept by (scheme, name) rather than by id.
    #
    # @return [String, nil] the concept's id
    def self.id_for_tree_with_name(tree_name, *names)
      return if names.blank? || tree_name.blank?

      for_tree(tree_name).with_internal_name(*names).pick(:id)
    end

    # @return [Array<String>] the ids of the concepts a scheme names by any of +names+
    def self.ids_for_tree_with_name(tree_name, *names)
      return [] if names.blank? || tree_name.blank?

      for_tree(tree_name).with_internal_name(*names).pluck(:id)
    end

    # Which concept scheme each of these concepts sits in, in the shape AnnotationPixie's editor
    # grouping reads. A concept carries a single concept_scheme_id, so every value holds exactly one
    # id - the array is what the caller's include? and intersect? are written against.
    #
    # @param concept_ids [Array<String>]
    # @return [Hash{String => Array<String>}] concept id => concept scheme ids
    def self.concept_scheme_ids_by_concept(concept_ids)
      return {} if concept_ids.blank?

      where(id: concept_ids)
        .reorder(nil)
        .pluck(:id, :concept_scheme_id)
        .to_h { |id, concept_scheme_id| [id.to_s, [concept_scheme_id.to_s]] }
    end

    # Concepts of a scheme, annotated with thing_count_with_subtree / thing_count_without_subtree
    # over +query+ (an ActiveRecord::Relation<Thing>, e.g. a StoredFilter's scoped query). Extracted
    # from Api::V4::ClassificationTreesController#facets so the REST endpoint and the MCP tools share
    # one implementation.
    #
    # Scheme membership is concepts.concept_scheme_id since #41458; it took an EXISTS over
    # classification_trees to answer the same question.
    def self.thing_counts_for_tree(concept_scheme_id:, query:, min_count_with_subtree: 0, min_count_without_subtree: 0)
      min_count_without_subtree_sanitized = ActiveRecord::Base.connection.quote(min_count_without_subtree)
      min_count_with_subtree = [min_count_with_subtree, min_count_without_subtree].max
      min_count_with_subtree_sanitized = ActiveRecord::Base.connection.quote(min_count_with_subtree)
      join_type = min_count_with_subtree.positive? || min_count_without_subtree.positive? ? 'INNER' : 'LEFT'
      subquery = query.where('things.id = ccc1.thing_id AND ccc1.concept_scheme_id = ?', concept_scheme_id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).select(1).to_sql

      join_sql = <<~SQL.squish
        #{join_type} JOIN LATERAL (SELECT ccc1.concept_id,
          COUNT(DISTINCT ccc1.thing_id) AS thing_count_with_subtree,
          COUNT(DISTINCT ccc1.thing_id) filter (WHERE ccc1.link_type IN ('direct', 'related')) AS thing_count_without_subtree
          FROM collected_concept_contents ccc1
          WHERE ccc1.hidden = FALSE AND EXISTS (#{subquery})
          GROUP BY ccc1.concept_id
        ) ccc ON ccc.concept_id = concepts.id
            AND COALESCE(ccc.thing_count_with_subtree, 0) >= #{min_count_with_subtree_sanitized}
            AND COALESCE(ccc.thing_count_without_subtree, 0) >= #{min_count_without_subtree_sanitized}
      SQL

      select_sql = <<~SQL.squish
        concepts.*,
        COALESCE(ccc.thing_count_with_subtree, 0) AS thing_count_with_subtree,
        COALESCE(ccc.thing_count_without_subtree, 0) AS thing_count_without_subtree
      SQL

      joins(join_sql).where(concept_scheme_id:).select(select_sql)
    end

    def self.concept_polygons
      DataCycleCore::ConceptPolygon.where(concept_id: pluck(:id))
    end

    # Every external key this concept answers to for a reader: its own, plus the keys of the concepts
    # it maps to - a mapping makes the target's contents reachable under this concept.
    def external_keys
      [external_key, *mapped_concepts.pluck(:external_key)].compact.join(', ')
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:Concept'
      }
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_system&.identifier })
        .merge(attributes)
    end

    def to_sync_data
      Rails.cache.fetch("sync_api/v1/concepts/#{id}/#{updated_at}/#{I18n.locale}", expires_in: 1.year + Random.rand(7.days)) do
        next if available_locales.exclude?(I18n.locale)

        as_json(
          only: [:id, :external_key, :uri, :order_a, :concept_scheme_id],
          include: { mapped_concepts: { only: [:id, :external_key], methods: [:external_system_identifier, :full_path] } },
          methods: [:parent_id, :name, :description, :external_system_identifier]
        )
          .deep_compact_blank
      end
    end

    def self.to_sync_data
      includes(:parent, :external_system, mapped_concepts: [:external_system, :concept_path]).filter_map(&:to_sync_data)
    end

    def parent_id
      parent&.id
    end

    def external_system_identifier
      external_system&.identifier
    end

    private

    def validate_color_format
      return unless color?

      errors.add(:ui_configs, :color_format) unless /^#((?:\h{1,2}){3,4})$/i.match?(color)
    end

    # Redmine #41458: the concept has one name per locale and one internal_name derived from them.
    # The old projection took the first *available* locale's name; the fallback list is
    # I18n.available_locales in order, so a concept named only in `en` keeps its `en` name.
    def set_internal_name
      return unless name_i18n_changed?

      available_translation = I18n.available_locales.drop_while { |locale| name(locale:).blank? }
      return if available_translation.blank?

      self.internal_name = DataCycleCore::MasterData::DataConverter.string_to_string(name(locale: available_translation.first)&.to_s)
    end

    def set_thing_counts
      self.thing_count_with_subtree = self['thing_count_with_subtree']
      self.thing_count_without_subtree = self['thing_count_without_subtree']
    end

    # @see DataCycleCore::ConceptLink - the `broader` link is what makes a concept reachable at all,
    # so it is created with the concept rather than left to the caller.
    def create_parent_link
      create_parent_concept_link!(parent: parent_concept)
    end
  end
end
