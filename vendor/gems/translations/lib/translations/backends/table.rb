# frozen_string_literal: true

require 'translations/plugins/cache'

module Translations
  module Backends
    module Table
      extend Translations::Backend::OrmDelegator

      def read(locale, **options)
        # puts "read(#{attribute}): translation_for(#{locale}, #{options})"
        translation_for(locale, **options).send(attribute)
      end

      def write(locale, value, **options)
        # puts "write(#{attribute}): translation_for(#{locale}, #{value}, #{options})"
        translation_for(locale, **options).send("#{attribute}=", value)
      end

      def each_locale
        translations.each { |t| yield t.locale.to_sym }
      end

      def self.included(backend)
        backend.extend ClassMethods
        backend.option_reader :association_name
        backend.option_reader :subclass_name
        backend.option_reader :foreign_key
        backend.option_reader :table_name
      end

      private

      def translations
        model.send(association_name)
      end

      module ClassMethods
        def apply_plugin(name)
          if name == :cache
            include self::Cache
            true
          else
            super
          end
        end

        def table_alias(locale)
          "#{table_name}_#{Translations.normalize_locale(locale)}"
        end
      end

      module Cache
        def translation_for(locale, **options)
          # puts "Cache: translation_for(#{locale}, #{options})"
          # use **options ?
          return super(locale, **options) if options.delete(:cache) == false
          if cache.key?(locale)
            cache[locale]
          else
            cache[locale] = super(locale, **options)
          end
        end

        def clear_cache
          model_cache && model_cache&.clear
        end

        private

        def cache
          model_cache || model.instance_variable_set(:"@__translation_#{association_name}_cache", {})
        end

        def model_cache
          model.instance_variable_get(:"@__translation_#{association_name}_cache")
        end
      end
    end
  end
end
