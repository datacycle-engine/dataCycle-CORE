# frozen_string_literal: true

module DataCycleCore
  class Schema
    # Property-row source for the /schema XLSX export.
    #
    # Unlike DataCycleCore::Schema::PropertyPresenter (the OpenAPI/detail-page
    # contract, where nesting is link-based via $ref), the spreadsheet needs the
    # embedded/object children expanded INLINE as indented rows. This presenter
    # walks the raw schema for that, resolving api_name through the single source
    # Content#api_name_for. Each node:
    #
    #   {
    #     api_name:        String,   # the v4 API name (Content#api_name_for — single source)
    #     label:           String,   # human label from the schema definition
    #     expected_type:   String,   # raw schema type (string/datetime/classification/embedded/linked/object/…)
    #     cardinality:     String,   # 'many' for embedded/linked collections, else 'one'
    #     flags:           Hash,     # translated / fulltext_search / classification / embedded / linked / recursive
    #     target_template: Array,    # linked/embedded → the template name(s) it points at (nil otherwise)
    #     tree_label:      String,   # classification → its classification-tree label (nil otherwise)
    #     nested:          Array     # child nodes for embedded/object (nil for leaves and recursion cut-offs)
    #   }
    #
    # Embedded templates are resolved once through a batched lookup (no N+1) and
    # recursion is cut off: a property pointing back at an ancestor template is
    # flagged `recursive` with `nested: nil` instead of looping forever.
    class XlsxPropertyPresenter
      # KNOWN DIVERGENCE (#50201 sign-off): the spreadsheet's type column is a
      # display label of the RAW schema type, while the detail page derives its
      # type chips from the OpenAPI fragment (FragmentReader). Keys
      # (Content#api_name_for) and skip rules (PropertyFilter) ARE shared; only
      # this label wording can differ (e.g. `geographic` → "Geographic" here vs
      # GeoCoordinates/GeoShape chips there).
      SCALAR_TYPE_LABELS = {
        'key' => 'Text',
        'string' => 'Text',
        'datetime' => 'DateTime',
        'classification' => 'Classification'
      }.freeze
      COLLECTION_TYPES = ['embedded', 'linked'].freeze
      CONTAINER_TYPES = ['embedded', 'object'].freeze

      # @param content [DataCycleCore::Thing] a template-thing (responds to
      #   #schema, #api_name_for, #template_name)
      # @param templates_by_name [Hash{String=>DataCycleCore::ThingTemplate}]
      #   optional shared lookup so a batch of templates resolves embeds once
      def initialize(content, templates_by_name: nil)
        @content = content
        @templates_by_name = templates_by_name || self.class.templates_by_name
      end

      # Default lookup of every template keyed by name, used to resolve embedded
      # references. Pass a shared one to resolve a batch of templates in one query.
      def self.templates_by_name
        DataCycleCore::ThingTemplate.all.index_by(&:template_name)
      end

      # The property view-model tree for the presented template — every attribute
      # the v4 API documents (PropertyFilter.documented?): internal attributes,
      # api-disabled, the internal key and the overlay variants whose base carries
      # the api name are hidden, everything the API delivers (incl. classifications
      # and combined, which the API aggregates) is kept.
      def nodes
        present(@content, Set[@content.template_name])
      end

      # Display label (for a leaf) of the raw schema type — container types carry
      # no scalar type, so they return nil.
      def self.type_label(expected_type)
        return nil if CONTAINER_TYPES.include?(expected_type) || expected_type == 'linked'

        SCALAR_TYPE_LABELS[expected_type] || expected_type.to_s.capitalize
      end

      private

      # All documented properties of one template thing.
      def present(content, visited)
        present_properties(content, content.schema['properties'], visited)
      end

      # Filters an arbitrary properties hash down to the documented attributes and
      # maps each survivor to a node. `content` owns api_name resolution, so
      # embedded children resolve against their own template thing (not the root's).
      def present_properties(content, properties, visited)
        (properties || {}).filter_map do |key, definition|
          next unless DataCycleCore::OpenApi::PropertyFilter.documented?(key, definition, properties)

          node_for(content, key, definition, visited)
        end
      end

      def node_for(content, key, definition, visited)
        type = definition['type']
        target = Array.wrap(definition['template_name']).presence
        # `visited` is a Set; call intersect? on it (Set#intersect? accepts the
        # Array) — Array#intersect?(Set) would raise, and this keeps the form
        # RuboCop's Style/ArrayIntersect wants so it isn't rewritten back.
        recursive = type == 'embedded' && visited.intersect?(Array.wrap(target))
        api_name = content.api_name_for(key, definition) || key

        {
          api_name:,
          label: definition['label'],
          expected_type: type,
          cardinality: COLLECTION_TYPES.include?(type) ? 'many' : 'one',
          flags: flags_for(api_name, definition, recursive:),
          target_template: target,
          tree_label: type == 'classification' ? RawDefinitionFlags.tree_label(definition) : nil,
          nested: recursive ? nil : nested_for(content, type, definition, target, visited)
        }
      end

      # Raw-definition markers via the shared RawDefinitionFlags (single source
      # with PropertyPresenter, #50201). `fulltext_search`/`recursive` are the
      # XLSX-specific keys the export view expects.
      def flags_for(key, definition, recursive:)
        {
          translated: RawDefinitionFlags.translated?(definition, key),
          fulltext_search: RawDefinitionFlags.fulltext?(definition),
          classification: RawDefinitionFlags.classification?(definition),
          embedded: RawDefinitionFlags.embedded?(definition),
          linked: RawDefinitionFlags.linked?(definition),
          recursive:
        }
      end

      def nested_for(content, type, definition, target, visited)
        case type
        when 'object'
          # inline sub-fields of the same thing — filtered against the same content
          present_properties(content, definition['properties'], visited)
        when 'embedded'
          name = Array.wrap(target).first
          template = name && @templates_by_name[name]
          return nil if template.nil?

          present(template.template_thing, visited + [name])
        end
      end
    end
  end
end
