# frozen_string_literal: true

module Translations
  module Plugins
    module ActiveRecord
      module TranslatedAttributes
        def translated_attributes
          {}
        end

        def attributes
          super.merge(translated_attributes)
        end
      end

      class AttributeMethodsBuilder < Module
        def initialize(*attribute_names)
          include TranslatedAttributes
          define_method :translated_attributes do
            super().merge(attribute_names.inject({}) do |attributes, name|
              attributes.merge(name.to_s => send(name))
            end)
          end
        end

        def included(model_class)
          model_class.class_eval do
            define_method :untranslated_attributes, ::ActiveRecord::Base.instance_method(:attributes)
          end
        end
      end
    end
  end
end
