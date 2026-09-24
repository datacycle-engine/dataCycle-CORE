# frozen_string_literal: true

module DataCycleCore
  class ConceptScheme < ApplicationRecord
    # @see DataCycleCore::Concept::History - same reason, written by
    # delete_concept_schemes_to_histories_trigger.
    class History < ApplicationRecord
      include ConceptSchemeExtensions::Queryable

      belongs_to :external_system, optional: true

      def readonly?
        true
      end
    end

    include ConceptSchemeExtensions::Queryable
    include ConceptSchemeExtensions::BulkImport
    include ConceptSchemeExtensions::CsvExport
    include ConceptSchemeExtensions::CacheInvalidation

    VISIBILITY_GROUPS = {
      contents: ['show', 'show_more', 'edit', 'compact'],
      dashboard_views: ['tile', 'list', 'tree_view'],
      dashboard_filters: ['filter'],
      interfaces: ['api', 'xml'],
      classification_administration: ['classification_overview', 'classification_administration'],
      content_tools: ['content_classifier']
    }.freeze

    validates :name, presence: true

    belongs_to :external_system

    has_many :concepts, dependent: :destroy

    has_many :things, -> { unscope(:order).distinct }, through: :concepts

    scope :by_external_systems_and_keys, -> { where(Array.new(_1.size) { '(external_system_id = ? AND external_key = ?)' }.join(' OR '), *_1.pluck(:external_system_id, :external_key).flatten) }
    # Asked as an EXISTS over concept_schemes rather than as a DISTINCT over concepts: concepts
    # carries no index leading with concept_scheme_id - the only one holding the column at all is
    # index_concepts_on_full_order_concept_scheme_id (order_a, id, concept_scheme_id), where it is
    # third - so a DISTINCT scans the table, while the EXISTS drives off this table's primary key
    # and stops at the first concept of each scheme.
    scope :with_concepts, -> { where(DataCycleCore::Concept.where('concepts.concept_scheme_id = concept_schemes.id').arel.exists) }

    def self.grouped_visibilities
      VISIBILITY_GROUPS
    end

    # The scheme behind an id that a caller must answer for even once it is gone - the API's
    # classifications endpoints name a scheme in the URL and still serve its deleted concepts.
    #
    # @return [DataCycleCore::ConceptScheme, DataCycleCore::ConceptScheme::History]
    def self.find_including_history(id)
      find_by(id:) || History.find(id)
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first)
      all.map { |v| v.to_select_option(locale) }
    end

    def self.to_sync_data
      includes(:external_system).map(&:to_sync_data)
    end

    # whether a change to this scheme or any of its concepts is allowed to webhook the affected
    # contents at all - the switch every webhook fan-out here and in Concept is gated on
    def trigger_webhooks?
      change_behaviour.to_a.include?('trigger_webhooks')
    end

    # Walks +concept_attributes+ as a path from a root of this scheme downwards, creating what is
    # missing on the way, and returns the deepest concept.
    #
    # @param concept_attributes [Array<String, Hash>] a name, or :name plus any of :external_system,
    #   :external_key, :uri, :internal
    # @return [DataCycleCore::Concept, nil] the concept the path ends at
    def create_concept(*concept_attributes)
      walk_concept_path(concept_attributes) do |scope, attributes, parent_concept|
        # All four are matched on, absent ones as NULL: two concepts of one parent may share a name
        # and differ only in the system that delivered them.
        identity = { name: attributes[:name], external_system: attributes[:external_system], external_key: attributes[:external_key], uri: attributes[:uri] }

        scope.find_by(identity) || concepts.create!(**identity, internal: attributes[:internal] || false, parent_concept:)
      end
    end

    # Same walk as #create_concept, but matching on the name alone and writing the external identity
    # onto a concept that already exists.
    def create_or_update_concept_by_name(*concept_attributes)
      walk_concept_path(concept_attributes, compact: true) do |scope, attributes, parent_concept|
        concept = scope.find_by(attributes.slice(:name))

        if concept.nil?
          concepts.create!(**attributes.slice(:name, :external_system_id, :external_key, :uri), parent_concept:)
        else
          concept.tap { _1.update!(attributes.slice(:external_system_id, :external_key, :uri)) }
        end
      end
    end

    def ancestors
      []
    end

    def visible?(context)
      visibility.include?(context)
    end

    def first_available_locale(*)
      :de
    end

    def to_api_default_values
      {
        '@id' => id,
        '@type' => 'skos:ConceptScheme'
      }
    end

    def to_hash
      { 'class_type' => self.class.to_s }
        .merge({ 'external_system' => external_system&.identifier })
        .merge(attributes)
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first)
      DataCycleCore::Filter::SelectOption.new(
        id:,
        name: ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon concept_scheme-icon'),
          name
        ].compact, ' '),
        html_class: model_name.param_key,
        dc_tooltip: "#{model_name.human(count: 1, locale:)}: #{name}",
        class_key: model_name.param_key
      )
    end

    def to_sync_data
      Rails.cache.fetch("sync_api/v1/concept_scheme/#{id}/#{updated_at}", expires_in: 1.year + Random.rand(7.days)) do
        as_json(only: [:id, :name])
          .merge({ 'external_system_identifier' => external_system&.identifier })
          .compact_blank
      end
    end

    def stored_filters
      DataCycleCore::StoredFilter.where('parameters::TEXT ILIKE ?', "%#{id}%")
    end

    # Renumbers order_a so a depth-first walk of the scheme comes out alphabetically. One statement:
    # the recursion builds every concept's path of internal names and ROW_NUMBER over it is the order.
    def sort_concepts_alphabetically!
      raw_sql = <<~SQL.squish
        UPDATE concepts
        SET order_a = w.order_a
        FROM (
            WITH RECURSIVE paths (id, full_internal_name) AS (
              SELECT concepts.id,
                ARRAY [concepts.internal_name]
              FROM concepts
                LEFT OUTER JOIN concept_links ON concept_links.child_id = concepts.id
                AND concept_links.link_type = 'broader'
              WHERE concept_links.id IS NULL
                AND concepts.concept_scheme_id = :id
              UNION
              SELECT concepts.id,
                paths.full_internal_name || concepts.internal_name
              FROM concept_links
                JOIN paths ON paths.id = concept_links.parent_id
                JOIN concepts ON concepts.id = concept_links.child_id
              WHERE concept_links.link_type = 'broader'
                AND concepts.concept_scheme_id = :id
            )
            SELECT paths.id,
              ROW_NUMBER() OVER (ORDER BY paths.full_internal_name ASC) AS order_a
            FROM paths
          ) w
        WHERE w.id = concepts.id;
      SQL

      ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [raw_sql, { id: }])
      )
    end

    private

    # The shared descent of #create_concept and #create_or_update_concept_by_name: each step looks
    # only among the children of the concept the previous one returned, so the same name may exist
    # under several parents.
    def walk_concept_path(concept_attributes, compact: false)
      parent_concept = nil

      concept_attributes
        .map { |attributes| normalize_concept_attributes(attributes, compact:) }
        .each do |attributes|
          scope = parent_concept.nil? ? concepts.roots : concepts.where(id: parent_concept.children.reorder(nil).select(:id))

          parent_concept = yield(scope, attributes, parent_concept)
        end

      parent_concept
    end

    def normalize_concept_attributes(attributes, compact:)
      return { name: attributes } if attributes.is_a?(String)

      compact ? attributes.compact_blank : attributes
    end
  end
end
