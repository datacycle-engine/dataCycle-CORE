# frozen_string_literal: true

module Translations
  module Plugins
    module AttributeMethods
      extend Plugin

      # Applies attribute_methods plugin for a given option value.
      included_hook do |model_class|
        include_attribute_methods_module(model_class, *names) if options[:attribute_methods]
      end

      private

      def include_attribute_methods_module(model_class, *attribute_names)
        require 'translations/plugins/active_record/attribute_methods_builder'
        module_builder = Plugins::ActiveRecord::AttributeMethodsBuilder
        model_class.include module_builder.new(*attribute_names)
      end
    end
  end
end
