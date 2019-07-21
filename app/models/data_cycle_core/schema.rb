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

      include Rails.application.routes.url_helpers

      DEFAULT_CONTENT_TABLE = 'things'

      def initialize(template_schema, schema: nil)
        @template_schema = template_schema
        @schema = schema
      end

      def self.load_template(path, template_index = 0)
        template = YAML.safe_load(File.open(path), [Symbol])[template_index]

        template[:data] = DataCycleCore::MasterData::ImportTemplates.transform_schema(schema: template[:data].dup,
                                                                                      content_table: DEFAULT_CONTENT_TABLE,
                                                                                      mixins: nil)
        errors = DataCycleCore::MasterData::ImportTemplates.validate(template)

        raise Error.new("'#{path}' contains invalid content template", errors) if errors.present?

        new(template[:data].as_json)
      end

      def clone_with_schema(schema = nil)
        clone.tap { |t| t.schema = schema }
      end

      def template_name
        @template_schema['name']
      end

      def schema_name
        @template_schema.dig('api', 'type') || @template_schema['schema_type']
      end

      def content_type
        @template_schema['content_type']
      end

      def property_definitions
        @template_schema['properties']
          .reject { |_, definition| definition['type'] == 'classification' || definition['type'] == 'key' }
          .reject { |_, definition| definition.dig('api', 'disabled') }
          .map { |key, definition|
            {
              domain: schema_name,
              label: key.camelize(:lower),
              range: resolve_range(definition),
              comment: nil
            }
          }.sort_by { |definition| [definition[:domain], definition[:label]] }
      end

      protected

      attr_writer :schema

      private

      def resolve_range(definition)
        if definition.dig('api', 'type')
          definition.dig('api', 'type')
        elsif definition['type'] == 'embedded'
          raise 'Cannot resolve embedded templates without schema' if @schema.nil?

          "/schema/#{@schema.template_by_template_name(definition['template_name']).schema_name}"
        elsif definition['type'] == 'linked' && definition['template_name'].present?
          raise 'Cannot resolve embedded templates without schema' if @schema.nil?

          "/schema/#{@schema.template_by_template_name(definition['template_name']).schema_name}"
        elsif definition['type'] == 'linked'
          '//schema.org/Thing'
        else
          case definition.dig('compute', 'type') || definition['type']
          when 'string'
            '//schema.org/Text'
          when 'datetime'
            '//schema.org/DateTime'
          when 'number'
            '//schema.org/Number'
          else
            definition['type']
          end
        end
      end
    end

    def self.content_types
      DataCycleCore::Thing.where(template: true).map(&:schema).map { |schema| schema['content_type'] }.uniq
    end

    def self.templates_with_content_type(content_type)
      DataCycleCore::Thing.where(template: true).where("schema ->> 'content_type' = ?", content_type)
    end

    def self.load_schema_from_database
      new(
        DataCycleCore::Thing.where(template: true).map { |t| Template.new(t.schema) }
      )
    end

    def self.count_templates(path)
      YAML.safe_load(File.open(path), [Symbol]).count
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
      @templates.find { |t| t.schema_name == schema_name }&.clone_with_schema(self)
    end

    private

    def initialize(templates)
      @templates = templates
    end
  end
end
