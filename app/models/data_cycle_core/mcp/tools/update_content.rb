# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Changes attributes of an existing content (a partial update) -- a writing tool, and
      # therefore registered only when main_config <mount>.mcp.write_enabled is set (see
      # Servers::Base#tool_classes). The write logic lives in Mcp::ContentWriter, shared with
      # CreateContent.
      #
      # The content is deliberately NOT looked up through base_query/api_scope: the endpoint scope is
      # a read filter, and a content just created through create_content sits in the "Entwurf" pool
      # by template default and would be findable in no endpoint. The boundary is the ability
      # (:update).
      class UpdateContent < Base
        self.tool_name = 'update_content'
        # Overwrites existing attribute values, hence destructive. The same call twice nevertheless
        # leaves the same state, so idempotent stays at the read default.
        self.annotations = { read_only_hint: false, destructive_hint: true }

        input_schema do |locale|
          {
            type: 'object',
            properties: {
              id: { type: 'string', format: 'uuid', description: argument_description('id', locale:) },
              # Deliberately open (no additionalProperties) -- see CreateContent: the keys depend on
              # the template and come from list_writable_attributes, not from get_schema.
              data: { type: 'object', description: argument_description('data', locale:) },
              locale: { type: 'string', description: argument_description('locale', locale:) }
            },
            required: ['id', 'data']
          }
        end

        # Writes the given attributes on behalf of the calling user (ability-checked in the ContentWriter).
        def call(arguments:, context:)
          DataCycleCore::Mcp::ContentWriter
            .for(arguments:, context:)
            .update(id: arguments[:id], data: arguments[:data])
        end
      end
    end
  end
end
