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
                                                                                      content_set: DEFAULT_CONTENT_TABLE,
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
          .reject { |_, definition| definition['type'] == 'key' } # definition['type'] == 'classification' ||
          .reject { |_, definition| definition.dig('api', 'disabled') }
          .map { |key, definition|
            if definition['type'] == 'object'
              Template.new(definition).property_definitions.map { |d| d.merge({ template_type: schema_name }) }
            else
              {
                template_type: schema_name,
                label: key.camelize(:lower),
                data_type: resolve_data_type(definition),
                comment: nil,
                translated: definition['storage_location'] == 'translated_value' || (definition['storage_location'] == 'column' && key == 'name') ? true : false
              }
            end
          }.flatten.sort_by { |definition| Array.wrap(definition[:template_type]) + [definition[:label]] }
      end

      protected

      attr_writer :schema

      private

      def resolve_data_type(definition)
        if definition.dig('api', 'type')
          "//schema.org/#{definition.dig('api', 'type')}"
        elsif definition['type'] == 'embedded'
          raise 'Cannot resolve embedded templates without schema' if @schema.nil?
          "/schema/#{@schema.template_by_template_name(definition['template_name']).schema_name}"
        elsif definition['type'] == 'linked'
          if definition['template_name'].present?
            raise 'Cannot resolve linked templates without schema' if @schema.nil?
            Array.wrap(@schema.template_by_template_name(definition['template_name']).schema_name)
              .compact
              &.map { |i| DataCycleCore::Thing.find_by(template_name: i, template: true).present? ? "/schema/#{i}" : "//schema.org/#{i}" }
          elsif definition['stored_filter'].present?
            raise 'Cannot resolve linked templates without schema' if @schema.nil?
            @schema.template_by_classification(definition.dig('stored_filter', 0, 'with_classification_aliases_and_treename', 'aliases'))
              .map { |i|
                if DataCycleCore::Thing.find_by(template_name: i, template: true).present?
                  "/schema/#{i}"
                else
                  Array.wrap(@schema.template_by_template_name(i)&.schema_name)
                    .compact
                    &.map { |item| DataCycleCore::Thing.find_by(template_name: item, template: true).present? ? "/schema/#{item}" : "//schema.org/#{item}" }
                    .presence
                end
              }.compact
          else
            '//schema.org/Thing'
          end
        elsif definition['type'] == 'classification'
          'classification'
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

    def template_by_classification(names)
      tree_name = 'Inhaltstypen'
      aliases = DataCycleCore::ClassificationAlias.for_tree(tree_name).with_internal_name(names).with_descendants

      aliases.map { |i|
        i.classifications.first.things.first&.template_name || i.internal_name
      }.compact.to_a.uniq
    end

    private

    def initialize(templates)
      @templates = templates
    end
  end
end
