# frozen_string_literal: true

module Translations
  module Backends
    module HashValued
      def read(locale, _options = nil)
        translations[locale]
      end

      def write(locale, value, _options = nil)
        translations[locale] = value
      end

      def each_locale
        translations.each { |l, _| yield l }
      end

      def self.included(backend_class)
        backend_class.extend ClassMethods
        backend_class.option_reader :column_affix
      end

      module ClassMethods
        def configure(options)
          options[:column_affix] = "#{options[:column_prefix]}%s#{options[:column_suffix]}"
        end
      end

      private

      def column_name
        @column_name ||= (column_affix % attribute)
      end
    end

    # private_constant :HashValued
  end
end
