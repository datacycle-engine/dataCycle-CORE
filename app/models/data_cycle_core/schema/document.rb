# frozen_string_literal: true

module DataCycleCore
  class Schema
    # Loads the generated OpenAPI 3.1 document for a locale and hands out per-template
    # presenters for the /schema UI (#50201). The UI is a pure CONSUMER — this class
    # only reads components/schemas (built by DataCycleCore::OpenApi::DocumentBuilder)
    # and resolves the routing between component names and template :ids.
    class Document
      def initialize(locale: I18n.default_locale)
        @locale = locale
      end

      # All component schemas, built once per instance.
      # NOTE: DocumentBuilder builds the whole document (all templates + paths). For a
      # single detail page that is heavier than needed; wrap in Rails.cache keyed by
      # locale + a templates version once profiling shows it matters.
      def schemas
        @schemas ||= DataCycleCore::OpenApi::DocumentBuilder.new(locale: @locale).call.dig('components', 'schemas') || {}
      end

      # component_name => routable template :id (its original template_name), for $ref links.
      def template_index
        @template_index ||= DataCycleCore::ThingTemplate.all.to_h do |template|
          [DataCycleCore::OpenApi::EntityBuilder.component_name(template.template_name), template.template_name]
        end
      end

      # @param id [String] a template_name or a schema.org type name (as in the route)
      # @return [TemplatePresenter, nil] nil when unknown (controller raises 404)
      def template(id)
        thing_template = find_template(id)
        return nil if thing_template.nil?

        component = schemas[DataCycleCore::OpenApi::EntityBuilder.component_name(thing_template.template_name)]
        return nil if component.nil?

        TemplatePresenter.new(template: thing_template, component:, template_index:)
      end

      private

      # Resolves the route :id like the previous controller: by template_name first,
      # then by schema.org type (api_schema_types carries the schema.org ancestors).
      def find_template(id)
        DataCycleCore::ThingTemplate.find_by(template_name: id) ||
          DataCycleCore::ThingTemplate.where('api_schema_types && ARRAY[?]::varchar[]', id.to_s).first
      end
    end
  end
end
