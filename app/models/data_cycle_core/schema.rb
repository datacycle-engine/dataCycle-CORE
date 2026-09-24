# frozen_string_literal: true

module DataCycleCore
  class Schema
    class Template
      class Error < StandardError
        attr_reader :details

        def initialize(message, details = nil)
          super(message)

          @details = details
        end

        def message
          super + "\nERROR:\n#{details.awesome_inspect}"
        end
      end

      include DataCycleCore::Common::Routing

      DEFAULT_CONTENT_TABLE = 'things'

      def initialize(template_schema, schema: nil)
        @template_schema = template_schema
        @schema = schema
      end

      def clone_with_schema(schema = nil)
        clone.tap { |t| t.schema = schema }
      end

      def template_name
        @template_schema['name']
      end

      def schema_name
        Array.wrap(@template_schema.dig('api', 'type')).reject { |s| s.start_with?('dc:', 'dcls:') }.presence || Array.wrap(@template_schema['schema_ancestors']).flatten.reject { |s| s.start_with?('dc:', 'dcls:') }
      end

      def content_type
        @template_schema['content_type']
      end

      # Name of the overlay template referenced by this template's overlay
      # property (e.g. "SnowResortOverlay"), or nil if the template has none.
      # `overlay_key` is the configured overlay attribute (see Feature::Overlay).
      def overlay_template_name(overlay_key)
        return if overlay_key.blank?

        @template_schema.dig('properties', overlay_key, 'template_name')
      end

      protected

      attr_writer :schema
    end

    # The three groups every /schema surface colours by — the cards, the
    # dependency table, the graph nodes and its legend. THE definition: it used to
    # be restated as a ternary in the view (three times), in the dependency graph
    # and again in JavaScript, and those five copies did not even agree on the
    # third group's name. The returned value doubles as the CSS modifier
    # (`schema-rel__dot--main` …), so there is no mapping table to keep in sync.
    # A blank content_type means "no own template" (shared schema.org / geo type).
    GROUPS = ['main', 'embedded', 'external'].freeze

    def self.node_group(content_type)
      return 'external' if content_type.blank?

      content_type == 'embedded' ? 'embedded' : 'main'
    end

    def self.content_types
      DataCycleCore::ThingTemplate.all.map(&:schema).pluck('content_type').uniq
    end

    def self.templates_with_content_type(content_type)
      DataCycleCore::ThingTemplate.where("schema ->> 'content_type' = ?", content_type).template_things
    end

    def self.load_schema_from_database
      new(
        DataCycleCore::ThingTemplate.all.map { |t| Template.new(t.schema) }
      )
    end

    attr_reader :templates

    def content_types
      @templates.map(&:content_type).uniq
    end

    def templates_with_content_type(content_type)
      @templates.select { |t| t.content_type == content_type }
    end

    def template_by_template_name(template_name)
      @templates.find { |t| t.template_name == template_name }&.clone_with_schema(self)
    end

    def template_by_schema_name(schema_name)
      @templates.find { |t| t.schema_name.include?(schema_name) }&.clone_with_schema(self)
    end

    def template_by_classification(names)
      tree_name = 'Inhaltstypen'
      aliases = DataCycleCore::Concept.for_tree(tree_name).with_internal_name(names).with_descendants

      aliases.filter_map { |i|
        i.things.first&.template_name || i.internal_name
      }.to_a.uniq
    end

    private

    def initialize(templates)
      @templates = templates
    end
  end
end
