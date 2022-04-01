# frozen_string_literal: true

require 'translations/util'

module Translations
  class Attributes < Module
    def self.plugin(plugin_name)
      include Translations::Plugins.load_plugin(plugin_name)
    end

    attr_reader :names
    attr_reader :options
    attr_reader :backend_class
    attr_reader :backend_name

    def initialize(*attribute_names, method: :accessor, backend: Translations.default_backend, **backend_options)
      raise ArgumentError, 'method must be one of: reader, writer, accessor' unless [:reader, :writer, :accessor].include?(method)
      @options = Translations.default_options.to_h.merge(backend_options)
      @names = attribute_names.map(&:to_s).freeze
      raise BackendRequired, 'Backend option required if Translations.config.default_backend is not set.' if backend.nil?
      @backend_name = backend

      attribute_names.each do |name|
        define_backend(name)
        define_reader(name) if [:accessor, :reader].include?(method)
        define_writer(name) if [:accessor, :writer].include?(method)
      end
    end

    def included(klass)
      @backend_class = Backends.load_backend(backend_name)
        .for(klass)
        .with_options(options.merge(model_class: klass))

      klass.include InstanceMethods
      klass.extend ClassMethods

      backend_class.setup_model(klass, names)

      backend_class
    end

    def each(&block)
      names.each(&block)
    end

    def inspect
      "#<Attributes (#{backend_name}) @names=#{names.join(', ')}>"
    end

    private

    def define_backend(attribute)
      module_eval <<-EOM, __FILE__, __LINE__ + 1
      def #{Backend.method_name(attribute)}
        translation_backends[:#{attribute}]
      end
      EOM
    end

    def define_reader(attribute)
      class_eval <<-EOM, __FILE__, __LINE__ + 1
        def #{attribute}(**options)
          return super() if options.delete(:super)
          #{set_locale_from_options_inline}
          translation_backends[:#{attribute}].read(locale, **options)
        end
        def #{attribute}?(**options)
          return super() if options.delete(:super)
          #{set_locale_from_options_inline}
          translation_backends[:#{attribute}].present?(locale, **options)
        end
      EOM
    end

    def define_writer(attribute)
      class_eval <<-EOM, __FILE__, __LINE__ + 1
        def #{attribute}=(value, **options)
          return super(value) if options.delete(:super)
          #{set_locale_from_options_inline}
          translation_backends[:#{attribute}].write(locale, value, **options)
        end
      EOM
    end

    # This string is evaluated inline in order to optimize performance of
    # getters and setters, avoiding extra steps where they are unneeded.
    def set_locale_from_options_inline
      <<-EOL
        if options[:locale]
          #{'Translations.enforce_available_locales!(options[:locale])' if I18n.enforce_available_locales}
          locale = options[:locale].to_sym
          options[:locale] &&= !!locale
        else
          locale = I18n.locale
        end
      EOL
    end

    module InstanceMethods
      def translation_backends
        @translation_backends ||= ::Hash.new do |hash, backend_name|
          next hash[backend_name.to_sym] if backend_name.is_a?(::String)
          hash[backend_name] = self.class.translation_backend_class(backend_name).new(self, backend_name.to_s)
        end
      end

      def available_locales
        raise NotImplementedError, 'available_locales is only available for :table backend' unless respond_to?(:translations)
        translations.pluck(:locale).map(&:to_sym).select { |i| i.in?(I18n.available_locales) }.sort_by { |t| I18n.available_locales.index t }
      end
      alias translated_locales available_locales

      def attributes
        super.merge(translated_attributes)
      end

      def translated_attributes
        self.class.translation_attributes.inject({}) do |attributes, name|
          attributes.merge(name.to_s => send(name))
        end
      end

      def initialize_dup(other)
        @translation_backends = nil
        super
      end
    end

    module ClassMethods
      def translation_modules
        ancestors.grep(Attributes)
      end

      def translation_attributes
        translation_modules.map(&:names).flatten.uniq
      end
      alias translated_attribute_names translation_attributes

      def translation_attribute?(attribute_name)
        translation_attributes.include?(attribute_name.to_s)
      end

      def translation_backend_class(backend_name)
        @backends ||= BackendsCache.new(self)
        @backends[backend_name.to_sym]
      end

      def class_name
        table_name[table_name_prefix.length..-(table_name_suffix.length + 1)].downcase.camelize.singularize # from Globalize
      end

      class BackendsCache < ::Hash
        def initialize(klass)
          # Preload backend mapping
          klass.translation_modules.each do |mod|
            mod.names.each { |attribute_name| self[attribute_name.to_sym] = mod.backend_class }
          end

          super() do |hash, name|
            mod = klass.translation_modules.find { |m| m.names.include? name.to_s }
            raise KeyError, "No backend for: #{name}." if mod.blank?
            hash[name] = mod.backend_class
          end
        end
      end
      private_constant :BackendsCache
    end
  end

  class BackendRequired < ArgumentError; end
end
