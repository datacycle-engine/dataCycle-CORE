# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Template name -> unpersisted Thing instance ("template thing"), with the same error for every
    # route by which a client names a template (Mcp::ContentWriter, Tools::ListWritableAttributes).
    # The error deliberately names the creatable templates: otherwise a client keeps guessing the
    # name (a "Tour" is a "Trail").
    module TemplateLookup
      module_function

      # Description of the template_name argument, shared by create_content and
      # list_writable_attributes. In one place, because a description naming the discovery route
      # otherwise gets carried along in one copy and forgotten in the other -- and the client reads
      # a different manual per tool for the same argument. Localized
      # (mcp.template_lookup.argument) rather than a constant: as a string literal it was the only
      # untranslatable text in either tool.
      def argument_description(locale: I18n.default_locale)
        DataCycleCore::Mcp::Translations.t('template_lookup.argument', locale:)
      end

      # @raise [DataCycleCore::Error::TemplateNotAllowedError] when the template does not exist.
      # @return [DataCycleCore::Thing] unpersisted instance of the template.
      def template_thing!(template_name)
        thing_template = DataCycleCore::ThingTemplate.find_by(template_name:)
        not_allowed!(template_name) if thing_template.nil?

        DataCycleCore::Thing.new(thing_template:)
      end

      # Like #template_thing!, and additionally raises when the template is not creatable (embedded
      # or without features.creatable). Scope nil as in ContentsController#create without an object
      # browser scope.
      def creatable_template_thing!(template_name)
        template_thing!(template_name).tap do |thing|
          not_allowed!(template_name) unless thing.creatable?(nil)
        end
      end

      # @raise [DataCycleCore::Error::TemplateNotAllowedError] always -- the error lists the
      #   creatable templates so the client stops guessing the name.
      def not_allowed!(template_name)
        raise DataCycleCore::Error::TemplateNotAllowedError.new(template_name, creatable_template_names)
      end

      # @return [Array<String>] names of all non-embedded, creatable templates, alphabetically.
      def creatable_template_names
        DataCycleCore::ThingTemplate.without_embedded.template_things.select { |t| t.creatable?(nil) }.map(&:template_name).sort
      end
    end
  end
end
