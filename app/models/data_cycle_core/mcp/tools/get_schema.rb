# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # A resource-like tool over DataCycleCore::Mcp::Document (the reader layer above
      # OpenApi::DocumentBuilder; the caching beneath it is explained at its .cache_key). Without
      # `template` it returns only the available template names (keeping the LLM context lean,
      # curated instead of dumping the complete OpenAPI document in one go).
      class GetSchema < Base
        self.tool_name = 'get_schema'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              template: { type: 'string', description: argument_description('template', locale:) }
            }
          }
        end

        # Without template: the list of available templates. With template: that template's schema.
        def call(arguments:, context:)
          document = DataCycleCore::Mcp::Document.new(locale: context[:locale])

          return { templates: document.template_index.values.sort.uniq } if arguments[:template].blank?

          schema = document.template(arguments[:template])
          return schema unless schema.nil?

          { error: DataCycleCore::Mcp::Translations.t('errors.unknown_template', template: arguments[:template]) }
        end
      end
    end
  end
end
