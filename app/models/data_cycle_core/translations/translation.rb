# frozen_string_literal: true

module DataCycleCore
  module Translations
    module Translation
      class << self
        def extended(model_class)
          return if model_class.respond_to? :translation_accessor

          model_class.extend DataCycleCore::Translations::Translates
          model_class.extend ClassMethods

          if (translates = DataCycleCore::Translations::Translation.config.accessor_method)
            model_class.singleton_class.send(:alias_method, translates, :translation_accessor)
          end

          model_class.include(DataCycleCore::Translations::ActiveRecord)
        end

        def storage
          RequestStore.store
        end

        def config
          @config ||= DataCycleCore::Translations::Configuration.new
        end

        [:accessor_method, :query_method, :default_backend, :default_options, :plugins, :default_accessor_locales].each do |method_name|
          define_method method_name do
            config.public_send(method_name)
          end
        end

        def configure
          yield config
        end

        def get_class_from_key(parent_class, key)
          klass_name = key.to_s.gsub(/(^|_)(.)/) { |x| x[-1..-1].upcase }
          parent_class.const_get(klass_name)
        end

        def normalize_locale(locale = I18n.locale)
          locale.to_s.downcase.tr('-', '_').to_s
        end
        alias normalized_locale normalize_locale

        def normalize_locale_accessor(attribute, locale = I18n.locale)
          "#{attribute}_#{normalize_locale(locale)}".tap do |accessor|
            unless CALL_COMPILABLE_REGEXP.match?(accessor)
              raise ArgumentError, "#{accessor.inspect} is not a valid accessor"
            end
          end
        end

        # def enforce_available_locales!(locale)
        #   raise Translation::InvalidLocale, locale unless locale.nil? || available_locales.include?(locale.to_sym)
        # end

        def available_locales
          I18n.available_locales
        end
      end

      module ClassMethods
        def translation_attributes
          []
        end
      end

      class NotImplementedError < StandardError; end
    end
  end
end
