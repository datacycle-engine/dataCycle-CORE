# frozen_string_literal: true

module DataCycleCore
  class Schema
    # View-model for a single property of a template, as delivered by the v4 API.
    #
    # This is the CONTRACT shared with the /schema index (#50201). It is a pure
    # CONSUMER of the generated OpenAPI document:
    #   * key / label / expected_type / cardinality come from the components/schemas
    #     fragment (built by EntityBuilder — the v4 truth, incl. skip rules);
    #   * the dataCycle-specific flags/links that OpenAPI does not carry
    #     (fulltext / overlay / classification tree) are read from the raw
    #     property definition — trivial data reads, no type/skip logic.
    #
    # Nesting is link-based ($ref -> /schema/:id), so recursion is structurally
    # impossible; embedded/linked targets are exposed as routable ids.
    class PropertyPresenter
      # Canonical display order of the filter facets surfaced by #categories, so the
      # header chips stay stable across templates (see TemplatePresenter#filter_categories).
      CATEGORY_ORDER = [:linked, :embedded, :classification, :geo, :translated, :fulltext].freeze

      # @param api_name       [String] the APIv4 key (the key in components/schemas)
      # @param fragment       [Hash]   the property's OpenAPI schema fragment
      # @param definition     [Hash]   the raw property definition (flags source); may be nil
      #                                 for envelope/aggregated keys (e.g. @type)
      # @param template_index [Hash]   component_name => routable template :id (for $ref links)
      # @param tree_label_ids [Hash, nil] pre-resolved tree_label => ctl_id map (from
      #   TemplatePresenter, resolved in one query). When nil, #classification_tree
      #   falls back to a per-property find_by so the presenter still works standalone
      #   (e.g. the /schema index building a single property).
      def initialize(api_name:, fragment:, definition: nil, template_index: {}, tree_label_ids: nil)
        @api_name = api_name
        @fragment = fragment || {}
        @definition = definition || {}
        @template_index = template_index
        @tree_label_ids = tree_label_ids
      end

      # The APIv4 key — the primary identifier shown in the UI.
      attr_reader :api_name

      # Human-readable label (secondary: subtitle/tooltip); the fragment's localized title.
      def label
        @fragment['title'].presence || @api_name.to_s
      end

      # @return [Array<Hash>] expected-type descriptors (see FragmentReader).
      # Memoized: #categories, #target_templates, #to_h and the detail view each
      # request it, and every call re-walks the OpenAPI fragment.
      def expected_type
        @expected_type ||= FragmentReader.descriptors(@fragment, @template_index)
      end

      # @return [:one, :many]
      def cardinality
        FragmentReader.cardinality(@fragment)
      end

      # @return [Hash{Symbol=>Boolean}] the API-consistent markers. The flags shared
      # with the XLSX export come from RawDefinitionFlags (single source, #50201);
      # geographic/overlay are detail-page-only.
      def flags
        @flags ||= {
          translated: RawDefinitionFlags.translated?(@definition, @api_name),
          classification: RawDefinitionFlags.classification?(@definition),
          embedded: RawDefinitionFlags.embedded?(@definition),
          linked: RawDefinitionFlags.linked?(@definition),
          geographic: type?('geographic'),
          overlay: @definition.dig('features', 'overlay').present?,
          fulltext: RawDefinitionFlags.fulltext?(@definition)
        }
      end

      # Classification tree link ({ label:, ctl_id: }) or nil.
      def classification_tree
        tree_label = RawDefinitionFlags.tree_label(@definition)
        return nil if tree_label.blank?

        { label: tree_label, ctl_id: tree_label_id(tree_label) }
      end

      # Routable target template ids for embedded/linked navigation (from the resolved $refs).
      def target_templates
        expected_type.filter_map { |descriptor| descriptor[:template] }.uniq
      end

      # Data-driven filter facets for this property, derived only from the flags and the
      # expected-type kinds we already compute — never from a hardcoded property-name map
      # (#50201). A property can belong to several facets (the header filter is OR-membership).
      def categories
        @categories ||= begin
          marks = flags
          kinds = expected_type.pluck(:kind)
          facets = []
          facets << :linked if marks[:linked] || marks[:embedded]
          facets << :embedded if marks[:embedded]
          facets << :classification if marks[:classification] || kinds.include?(:concept)
          facets << :geo if marks[:geographic] || kinds.include?(:geo)
          facets << :translated if marks[:translated]
          facets << :fulltext if marks[:fulltext]
          facets
        end
      end

      # The full view-model contract (also consumed by the index, #50201).
      def to_h
        {
          api_name:,
          label:,
          expected_type:,
          cardinality:,
          flags:,
          classification_tree:,
          target_templates:
        }
      end

      private

      # Uses the batch-resolved map when TemplatePresenter provided one; otherwise
      # resolves a single label directly (standalone use). An unknown label yields nil.
      def tree_label_id(name)
        return @tree_label_ids[name] unless @tree_label_ids.nil?

        DataCycleCore::ConceptScheme.find_by(name:)&.id
      end

      def type?(type)
        @definition['type'] == type
      end
    end
  end
end
