# frozen_string_literal: true

module DataCycleCore
  class Schema
    # View-model for one template's detail page (#50201). Template-level metadata comes
    # from the ThingTemplate; the property list comes from the template's OpenAPI
    # component (already filtered by the v4 skip rules in EntityBuilder). Each property
    # is enriched with its raw definition so PropertyPresenter can read the dc flags.
    class TemplatePresenter
      # Type-path segments that are dataCycle-internal namespaces (dc:/dcls:) and are
      # never shown; stripped from every displayed schema.org type path.
      INTERNAL_TYPE_PREFIXES = ['dc:', 'dcls:'].freeze

      # @param template       [DataCycleCore::ThingTemplate]
      # @param component       [Hash] the template's components/schemas entry
      # @param template_index  [Hash] component_name => routable :id (for $ref links)
      def initialize(template:, component:, template_index: {})
        @template = template
        @component = component || {}
        @template_index = template_index
      end

      delegate :template_name, to: :@template

      # schema.org type "path" of the template — the same value the index cards
      # show as their subtitle. Mirrors Schema::Template#schema_name (api.type,
      # dc:/dcls: internals stripped, falling back to the schema ancestors) so the
      # detail page's sub-title path matches the /schema overview.
      def schema_name
        api_type_path.presence || strip_internal_types(Array.wrap(schema_ancestors).flatten)
      end

      # schema.org type "path(s)" for the detail page: one array of segments per path,
      # preserving the hierarchy the way schema.org renders it (Thing > Place >
      # Accommodation). api.type is a single path; schema_ancestors may carry several.
      # dc:/dcls: internals are stripped. Unlike #schema_name (flat, used by the /schema
      # index subtitle) this keeps each path grouped, so the view renders one line per
      # path instead of one line per segment (#50201).
      def schema_type_paths
        api_path = api_type_path

        paths =
          if api_path.present?
            [api_path]
          else
            @template.schema_ancestors.map { |path| strip_internal_types(path) }
          end

        paths.compact_blank
      end

      # entity | embedded | container
      delegate :content_type, to: :@template

      # schema.org / @type origin of the whole template.
      delegate :api_schema_types, to: :@template

      delegate :schema_ancestors, to: :@template

      delegate :thing_count, to: :@template

      delegate :template_paths, to: :@template

      # The delivered properties as PropertyPresenters (in component order = api order).
      def properties
        @properties ||= (@component['properties'] || {}).map do |api_name, fragment|
          PropertyPresenter.new(
            api_name:,
            fragment:,
            definition: raw_definitions[api_name],
            template_index: @template_index,
            tree_label_ids:
          )
        end
      end

      # The filter facets actually present across the rendered properties, in the
      # canonical order — drives the header chips, so a template only ever offers
      # filters that match at least one shown property (never a hardcoded list, #50201).
      def filter_categories
        @filter_categories ||= begin
          present = properties.flat_map(&:categories).uniq
          PropertyPresenter::CATEGORY_ORDER.select { |category| present.include?(category) }
        end
      end

      # Full contract (template head + property list).
      def to_h
        {
          template_name:,
          content_type:,
          api_schema_types:,
          schema_ancestors:,
          thing_count:,
          template_paths:,
          properties: properties.map(&:to_h)
        }
      end

      private

      # The api.type type path (a single schema.org hierarchy), dc:/dcls: internals removed.
      def api_type_path
        strip_internal_types(@template.schema&.dig('api', 'type'))
      end

      # Removes dataCycle-internal (dc:/dcls:) segments from one type path.
      def strip_internal_types(segments)
        Array.wrap(segments).reject { |segment| segment.start_with?(*INTERNAL_TYPE_PREFIXES) }
      end

      # api_name => raw property definition, so the property presenter can read the
      # dc-specific flags OpenAPI does not carry. Uses the canonical api_name_for so
      # the join key matches the component key exactly (no second key logic).
      #
      # Several source properties can resolve to the same api_name — an overlay
      # variant collapses onto its base key (Feature::Content::Overlay#api_name_for).
      # The base property owns the dc flags, so we let a non-overlay definition win
      # regardless of iteration order (a plain `||=` would keep whichever came first).
      def raw_definitions
        @raw_definitions ||= begin
          thing = @template.template_thing
          thing.property_names.each_with_object({}) do |name, acc|
            api_name = thing.api_name_for(name)
            next if api_name.blank?

            definition = thing.properties_for(name)
            next if acc.key?(api_name) && overlay_definition?(definition)

            acc[api_name] = definition
          end
        end
      end

      # True for an overlay *variant* property (the one that collapses onto a base
      # key); identified by features.overlay.overlay_for, same as the overlay feature.
      def overlay_definition?(definition)
        definition&.dig('features', 'overlay', 'overlay_for').present?
      end

      # tree_label => ConceptScheme#id, resolved in ONE query for the whole
      # template so PropertyPresenter#classification_tree does not run a find_by per
      # property (N+1). Unknown labels are simply absent (=> ctl_id nil).
      def tree_label_ids
        @tree_label_ids ||= begin
          labels = raw_definitions.values.filter_map { |definition| definition['tree_label'].presence }.uniq
          labels.empty? ? {} : DataCycleCore::ConceptScheme.where(name: labels).pluck(:name, :id).to_h
        end
      end
    end
  end
end
