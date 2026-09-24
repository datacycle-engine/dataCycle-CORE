# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Creates a new content -- the first writing tool, and therefore registered only when
      # main_config <mount>.mcp.write_enabled is set (see Servers::Base#tool_classes).
      # The actual write logic lives in Mcp::ContentWriter, shared with UpdateContent.
      class CreateContent < Base
        self.tool_name = 'create_content'
        # Two calls create two contents, so not idempotent -- but nothing existing is overwritten,
        # which leaves destructive at the read default.
        self.annotations = { read_only_hint: false, idempotent_hint: false }

        input_schema do |locale|
          {
            type: 'object',
            properties: {
              template_name: { type: 'string', description: DataCycleCore::Mcp::TemplateLookup.argument_description(locale:) },
              # Deliberately open (no additionalProperties): the keys are the attribute names of the
              # respective template and are therefore not enumerable here. The source of the names is
              # list_writable_attributes -- NOT get_schema, whose API names ("odta:length") land in
              # ignored_attributes when writing.
              data: { type: 'object', description: argument_description('data', locale:) },
              locale: { type: 'string', description: argument_description('locale', locale:) }
            },
            required: ['template_name', 'data']
          }
        end

        # Creates the content on behalf of the calling user (ability-checked in the ContentWriter).
        def call(arguments:, context:)
          DataCycleCore::Mcp::ContentWriter
            .for(arguments:, context:)
            .create(template_name: arguments[:template_name], data: arguments[:data])
        end
      end
    end
  end
end
