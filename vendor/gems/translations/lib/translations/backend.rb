# frozen_string_literal: true

require 'translations/backend/orm_delegator'

module Translations
  module Backend
    include Enumerable

    attr_reader :attribute
    attr_reader :model

    def initialize(*args)
      @model = args[0]
      @attribute = args[1]
    end

    def each_locale
    end

    def each
      each_locale { |locale| yield Translation.new(self, locale) }
    end

    def locales
      map(&:locale)
    end

    def present?(locale, options = {})
      Util.present?(read(locale, options))
    end

    def options
      self.class.options
    end

    # Extend included class with +setup+ method and other class methods
    def self.included(base)
      base.extend ClassMethods
      def base.options
        @options
      end
      base.option_reader :model_class
    end

    def self.method_name(attribute)
      @backend_method_names ||= {}
      @backend_method_names[attribute] ||= "#{attribute}_backend"
    end

    module ClassMethods
      def setup(&block)
        if @setup_block
          setup_block = @setup_block
          @setup_block = lambda do |*args|
            class_exec(*args, &setup_block)
            class_exec(*args, &block)
          end
        else
          @setup_block = block
        end
      end

      def inherited(subclass)
        subclass.instance_variable_set(:@setup_block, @setup_block)
        subclass.instance_variable_set(:@options, @options)
      end

      def setup_model(model_class, attribute_names)
        setup_block = @setup_block
        return unless setup_block
        model_class.class_exec(attribute_names, options, &setup_block)
      end

      def with_options(options = {})
        configure(options) if respond_to?(:configure)
        options.freeze
        Class.new(self) do
          @options = options
        end
      end

      def option_reader(attribute_name)
        module_eval <<-EOM, __FILE__, __LINE__ + 1
          def self.#{attribute_name}
            options[:#{attribute_name}]
          end
          def #{attribute_name}
            self.class.options[:#{attribute_name}]
          end
        EOM
      end

      def for(_model_class)
        self
      end

      def apply_plugin(_)
        false
      end

      def inspect
        name ? super : "#<#{superclass.name}>"
      end
    end

    Translation = Struct.new(:backend, :locale) do
      def read(options = {})
        backend.read(locale, options)
      end

      def write(value, options = {})
        backend.write(locale, value, options)
      end
    end
  end
end
