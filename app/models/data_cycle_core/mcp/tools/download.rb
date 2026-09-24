# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Returns a download URL rather than the file itself: the REST downloads are synchronous
      # ActionController::Live streaming (Content-Disposition: attachment), not JSON -- an MCP tool
      # cannot reproduce a live response stream in-process.
      class Download < Base
        include DataCycleCore::Mcp::BadRequest

        self.tool_name = 'download'
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              id: openapi_property('downloadThing', 'content_id', locale:, extra: argument_description('id', locale:)),
              # format: dynamic per instance and target
              # (Feature::Download.enabled_serializer_for_download?), with no static enum derivable
              # from the OpenAPI documentation -- hence a free string.
              format: { type: 'string', description: argument_description('format', locale:) }
            },
            required: ['format']
          }
        end

        # Builds the signed download URL for a single content or for the whole endpoint.
        def call(arguments:, context:)
          stored_filter = context[:stored_filter]
          target = arguments[:id].present? ? context[:base_query].query.find(arguments[:id]) : stored_filter

          unless DataCycleCore::Feature::Download.allowed?(target, :content) &&
                 DataCycleCore::Feature::Download.enabled_serializer_for_download?(target, :content, arguments[:format])
            bad_request!('format', "download not allowed for format '#{arguments[:format]}' on this target", 'invalid_format')
          end

          path = if arguments[:id].present?
                   Rails.application.routes.url_helpers.api_v4_download_thing_path(id: stored_filter.id, content_id: arguments[:id], serialize_format: arguments[:format])
                 else
                   Rails.application.routes.url_helpers.api_v4_download_endpoint_path(id: stored_filter.id, serialize_format: arguments[:format])
                 end

          {
            url: "#{context[:base_url]}#{path}",
            format: arguments[:format],
            # Localized like every other client-visible text: as a German literal this hint was the
            # only part of the response that did not follow the mount's language.
            note: DataCycleCore::Mcp::Translations.t('tools.download.note')
          }
        end
      end
    end
  end
end
