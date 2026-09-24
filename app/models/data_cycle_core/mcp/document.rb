# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Reader layer: the single source for MCP tool input schemas. Like
    # DataCycleCore::Schema::Document (#50201) it reads from the generated OpenAPI document --
    # no parallel schema source of its own, no UI presenter logic.
    class Document
      # locale: nil is treated as "not given". Callers read the language from the server context
      # (context[:locale]), which does not necessarily carry it -- normalising it here spares every
      # caller the same `|| I18n.default_locale`, which otherwise gets forgotten in one place and
      # passes a nil through to the DocumentBuilder from there.
      def initialize(locale: nil)
        @locale = locale || I18n.default_locale
      end

      # The full OpenAPI document (paths + components), memoized. Single builder
      # call backing #schemas and #path_parameter_schema alike.
      def document
        @document ||= DataCycleCore::OpenApi::DocumentBuilder.new(locale: @locale).call
      end

      # All component schemas (shared + per-template + AnyEntity), memoized.
      def schemas
        @schemas ||= document.dig('components', 'schemas') || {}
      end

      # component_name => routable template :id (its original template_name)
      def template_index
        @template_index ||= DataCycleCore::ThingTemplate.all.to_h do |template|
          [DataCycleCore::OpenApi::EntityBuilder.component_name(template.template_name), template.template_name]
        end
      end

      # @param id [String] a template_name or a schema.org type name (as in the route)
      # @return [Hash, nil] the already-localized OpenAPI component fragment, or nil when unknown
      def template(id)
        thing_template = find_template(id)
        return nil if thing_template.nil?

        schemas[DataCycleCore::OpenApi::EntityBuilder.component_name(thing_template.template_name)]
      end

      # Resolves a single path parameter's JSON-Schema (+ description) for a given
      # OpenAPI operationId, so MCP tool input_schemas can derive their properties
      # from the same source instead of duplicating the shape by hand.
      # @param operation_id [String] e.g. 'getEndpointContent'
      # @param param_name [String] the OpenAPI parameter name, e.g. 'content_id'
      # @return [Hash, nil] {'type' => ..., 'description' => ...}, or nil when not found
      def path_parameter_schema(operation_id, param_name)
        operation = find_operation(operation_id)
        return nil if operation.nil?

        param = resolve_parameters(operation['parameters']).find { |p| p['name'] == param_name }
        return nil if param.nil?

        param['schema'].to_h.merge('description' => param['description']).compact
      end

      private

      def find_template(id)
        DataCycleCore::ThingTemplate.find_by(template_name: id) ||
          DataCycleCore::ThingTemplate.where('api_schema_types && ARRAY[?]::varchar[]', id.to_s).first
      end

      # Searches ALL operations of a path item, not only get/post: the document now also carries
      # put (9), patch (10) and delete (2) -- 21 operations measured that a fixed verb list would
      # leave invisible (updateUser, putTimeseries, deleteExternalSourceContent ...). A tool naming
      # one of them as its source would get "has no parameter" although the parameter exists, and
      # the search for the cause would run in the wrong direction.
      #
      # An operation is recognised by its operationId rather than by a verb list, so a future verb
      # needs nothing added here. That also excludes the non-operations of a path item (servers,
      # parameters, summary), which carry none.
      def find_operation(operation_id)
        document['paths'].each_value do |path_item|
          operation = path_item.each_value.find { |o| o.is_a?(Hash) && o['operationId'] == operation_id }
          return operation if operation
        end
        nil
      end

      def resolve_parameters(parameters)
        Array(parameters).map { |param| param['$ref'] ? document.dig('components', 'parameters', param['$ref'].to_s.split('/').last) : param }
      end
    end
  end
end
