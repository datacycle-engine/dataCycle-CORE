# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Resources
      # Domain base class for MCP resources -- the counterpart to Tools::Base (see there).
      # Deliberately simpler than MCP::Resource/MCP::ResourceTemplate (SDK): an instance method
      # #contents(context:) (or with template variables) rather than a class method --
      # to_mcp_resource(_template) adapts to the SDK interface. `uri`/`uri_template` sit on the class
      # (not as a server argument), so URI and resolution logic stay in one place.
      class Base
        class << self
          attr_accessor :resource_name, :description_key, :mime_type, :uri, :uri_template

          # Localized resource description from config/locales/{de,en}.mcp.yml
          # (mcp.resources.<description_key>.description).
          def description(locale: I18n.default_locale, **interpolations)
            DataCycleCore::Mcp::Translations.t("resources.#{description_key}.description", locale:, **interpolations)
          end

          # Builds a static MCP::Resource subclass (one fixed URI, no template).
          def to_mcp_resource(description:)
            domain_resource_class = self

            MCP::Resource.define(uri:, name: resource_name, description:, mime_type:) do |server_context:|
              domain_resource_class.new.contents_response(uri, context: server_context)
            end
          end

          # Builds an MCP::ResourceTemplate subclass (a URI with {variables}, e.g. {template}).
          def to_mcp_resource_template(description:)
            domain_resource_class = self

            MCP::ResourceTemplate.define(uri_template:, name: resource_name, description:, mime_type:) do |server_context:, **params|
              domain_resource_class.new.contents_response(domain_resource_class.resolve_uri(params), context: server_context, **params)
            end
          end

          # Replaces {variables} in the uri_template with the concrete call parameters, for the
          # resulting TextContents#uri (RFC 6570 level 1, the same restriction the SDK itself uses
          # when matching).
          def resolve_uri(params)
            uri_template.gsub(/\{(\w+)\}/) { params[Regexp.last_match(1).to_sym].to_s }
          end
        end

        # Wraps #contents in an MCP::Resource::TextContents for the given uri.
        def contents_response(uri, context:, **params)
          result = contents(context:, **params)
          MCP::Resource::TextContents.new(text: JSON.generate(result), uri:, mime_type: self.class.mime_type)
        end

        # Abstract: subclasses return the resource's data as a Hash/Array to be JSON-serialized.
        def contents(context:, **params)
          raise NotImplementedError, "#{self.class} must implement #contents"
        end
      end
    end
  end
end
