# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Resources
      # The ResourceTemplate equivalent of Tools::GetSchema (see there for the tool variant) -- one
      # type schema per URI (datacycle://schema/{template}), so MCP clients can retrieve it through
      # resources/read as well and not only as a tool call.
      class SchemaTemplate < Base
        self.resource_name = 'schema_template'
        self.description_key = 'schema_template'
        self.mime_type = 'application/json'
        self.uri_template = 'datacycle://schema/{template}'

        # Returns the schema for the given template name, or an error hash if unknown.
        #
        # The same error text as in Tools::GetSchema and from the same source
        # (mcp.errors.unknown_template): both answer the same question, and as a literal it stood
        # here a second time -- in English, while the description of the same resource is localized.
        # locale explicitly from the context: the language bracket in Tools::Base applies to tool
        # calls only, and a resources/read does not run through it.
        def contents(template:, context:)
          locale = context[:locale] || I18n.default_locale
          schema = DataCycleCore::Mcp::Document.new(locale:).template(template)
          return schema unless schema.nil?

          { error: DataCycleCore::Mcp::Translations.t('errors.unknown_template', locale:, template:) }
        end
      end
    end
  end
end
