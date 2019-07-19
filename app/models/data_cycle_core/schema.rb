# frozen_string_literal: true

module DataCycleCore
  class Schema
    class Template
      include Rails.application.routes.url_helpers

      def initialize(template_schema)
        @template_schema = template_schema
      end

      def property_definitions
        @template_schema['properties']
          .reject { |_, definition| definition['type'] == 'classification' || definition['type'] == 'key' }
          .reject { |_, definition| definition.dig('api', 'disabled') }
          .map { |key, definition|
            {
              domain: @template_schema.dig('api', 'type') || @schema['schema_type'],
              label: key.camelize(:lower),
              range: resolve_range(definition),
              comment: nil
            }
          }.sort_by { |definition| [definition[:domain], definition[:label]] }
      end

      private

      def resolve_range(definition)
        if definition.dig('api', 'type')
          definition.dig('api', 'type')
        elsif definition['type'] == 'embedded'
          DataCycleCore::Thing.find_by(template: true, template_name: definition['template_name']).schema.then { |schema|
            [
              schema.dig('api', 'type'),
              schema['schema_type']
            ]
          }.reject(&:blank?).first.then { |type| "/schema/#{type}" }
        else
          case definition.dig('compute', 'type') || definition['type']
          when 'string'
            '//schema.org/Text'
          when 'datetime'
            '//schema.org/DateTime'
          when 'number'
            '//schema.org/Number'
          when 'linked'
            '//schema.org/Thing'
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
  end
end
