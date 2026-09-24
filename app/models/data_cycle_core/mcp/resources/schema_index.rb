# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Resources
      # List of the content templates whose schema is retrievable through SchemaTemplate. In the
      # single-endpoint server (context[:stored_filter] set) it is restricted to the templates that
      # actually occur in the endpoint; instance-wide it is the full list of the OpenAPI document --
      # the same set the get_schema tool names without an argument.
      #
      # The endpoint recognises itself by :stored_filter, NOT by :base_query: the latter exists on
      # both mounts since the shared tools were released (instance-wide from Mcp::ApiScope). Tied to
      # :base_query, this resource would have switched silently to "templates that currently have
      # contents" instance-wide -- a different answer than get_schema gives to the same question, and
      # one that reads a template without contents as "no schema available".
      class SchemaIndex < Base
        self.resource_name = 'schema_index'
        self.description_key = 'schema_index'
        self.mime_type = 'application/json'
        self.uri = 'datacycle://schema'

        # Lists the available template names, scoped to the endpoint's contents if there is one.
        def contents(context:)
          document = DataCycleCore::Mcp::Document.new(locale: context[:locale])

          templates = if context[:stored_filter]
                        # reorder(nil): the endpoint's query carries its own ORDER BY (e.g. the
                        # endpoint's sort_parameters), which Postgres rejects when combined with
                        # DISTINCT unless the ordered column is also selected/plucked.
                        context[:base_query].query.reorder(nil).distinct.pluck(:template_name).compact.sort
                      else
                        document.template_index.values.sort.uniq
                      end

          { templates: }
        end
      end
    end
  end
end
