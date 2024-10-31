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

      def property_definitions
        @template_schema['properties']
          .reject { |_, definition| definition['type'] == 'key' }
          .reject { |_, definition| definition.dig('api', 'v4', 'disabled').nil? ? definition.dig('api', 'disabled') : definition.dig('api', 'v4', 'disabled') }
          .map { |key, definition|
            if definition['type'] == 'object'
              Template.new(definition).property_definitions.map { |d| d.merge({ template_type: schema_name }) }
            else
              {
                template_type: schema_name,
                label: key.camelize(:lower),
                data_type: resolve_data_type(definition),
                comment: definition['type'] == 'classification' ? definition['tree_label'] : nil,
                comment_link: definition['tree_label'].present? ? DataCycleCore::ClassificationTreeLabel.find_by(name: definition['tree_label'])&.id : nil,
                translated: definition['storage_location'] == 'translated_value' || (definition['storage_location'] == 'column' && key == 'name') ? true : false,
                fulltext_search: definition.dig('search') == true,
                embedded: definition['type'] == 'embedded'
              }
            end
          }.flatten.sort_by { |definition| Array.wrap(definition[:template_type]) + [definition[:label]] }
      end

      protected

      attr_writer :schema

      private

      def classification_template_translator(classification)
        {
          'Organisation' => 'Organization'
        }[classification]
      end

      def resolve_data_type(definition)
        return "//schema.org/#{definition.dig('api', 'type')}" if definition.dig('api', 'type')

        case definition['type']
        when 'embedded'
          raise 'Cannot resolve embedded templates without schema' if @schema.nil?
          "/schema/#{definition['template_name']}"
        when 'linked'
          if definition['template_name'].present?
            raise 'Cannot resolve linked templates without schema' if @schema.nil?
            "/schema/#{definition['template_name']}"
          elsif definition['stored_filter'].present?
            raise 'Cannot resolve linked templates without schema' if @schema.nil?
            @schema.template_by_classification(definition.dig('stored_filter', 0, 'with_classification_aliases_and_treename', 'aliases'))
              .filter_map { |i| i.sub(/^Organisation$/, 'Organization') }
          else
            '//schema.org/Thing'
          end
        when 'classification'
          'classification'
        else
          case definition['type']
          when 'string'
            '//schema.org/Text'
          when 'datetime'
            '//schema.org/DateTime'
          when 'number'
            '//schema.org/Number'
          when 'schedule'
            '//schema.org/Schedule'
          when 'geographic'
            '//schema.org/line'
          else
            definition['type']
          end
        end
      end
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

    def self.count_templates(path)
      YAML.safe_load(File.open(path), permitted_classes: [Symbol]).count
    end

    def self.load_schema(paths)
      new(
        Array(paths).map { |path|
          (0..(count_templates(path) - 1)).map { |template_index| Template.load_template(path, template_index) }
        }.flatten
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
      aliases = DataCycleCore::ClassificationAlias.for_tree(tree_name).with_internal_name(names).with_descendants

      aliases.filter_map { |i|
        i.classifications.first.things.first&.template_name || i.internal_name
      }.to_a.uniq
    end

    private

    def initialize(templates)
      @templates = templates
    end
  end
end
