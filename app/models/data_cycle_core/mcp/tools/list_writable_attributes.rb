# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Discovery for create_content/update_content: the writable attribute names of a template.
      # A tool of its own rather than an extension of get_schema, because the two lists serve
      # different namespaces -- get_schema/list_attributes describe the READING v4 API (api_name),
      # while this is about the internal property names writing goes through (see
      # Mcp::WritableAttributes).
      class ListWritableAttributes < Base
        self.tool_name = 'list_writable_attributes'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              template_name: { type: 'string', description: DataCycleCore::Mcp::TemplateLookup.argument_description(locale:) }
            },
            required: ['template_name']
          }
        end

        # Returns the template's writable attributes together with API name, type, unit and concept
        # scheme. No ability check: the list is a property of the template, not data.
        # locale: the labels in the mount's language, like every other description of this server.
        def call(arguments:, context:)
          template_name = arguments[:template_name]
          content = DataCycleCore::Mcp::TemplateLookup.template_thing!(template_name)

          {
            template_name:,
            creatable: content.creatable?(nil),
            attributes: DataCycleCore::Mcp::WritableAttributes.new(content, locale: context[:locale] || I18n.default_locale).to_a
          }
        end
      end
    end
  end
end
