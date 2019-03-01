# frozen_string_literal: true

module Translations
  class Configuration
    RESERVED_OPTION_KEYS = [:backend, :model_class].freeze

    attr_accessor :accessor_method
    attr_accessor :query_method
    attr_reader :default_options

    def plugin(plugin_name)
      attributes_class.send(:plugin, plugin_name)
    end

    def plugins(*names)
      names.each(&method(:plugin))
    end

    attr_accessor :default_backend

    def default_accessor_locales
      if @default_accessor_locales.is_a?(Proc)
        @default_accessor_locales.call
      else
        @default_accessor_locales
      end
    end
    attr_writer :default_accessor_locales

    def initialize
      @accessor_method = :translates
      @query_method = :i18n
      @default_backend = :jsonb
      @default_accessor_locales = -> { Translations.available_locales }
      @default_options = Options[{
        cache: true,
        presence: true,
        query: true
      }]
      plugins(:query)
    end

    def attributes_class
      @attributes_class ||= Class.new(Translations::Attributes)
    end

    class ReservedOptionKey < RuntimeError; end

    class Options < ::Hash
      def []=(key, _)
        raise Configuration::ReservedOptionKey, "Default options may not contain the following reserved key: #{key}" if RESERVED_OPTION_KEYS.include?(key)
        super
      end
    end
  end
end
