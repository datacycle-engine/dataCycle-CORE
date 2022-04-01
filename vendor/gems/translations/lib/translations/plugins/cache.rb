# frozen_string_literal: true

module Translations
  module Plugins
    module Cache
      extend Plugin

      # Applies cache plugin to attributes.
      included_hook do |model_class, backend_class|
        if options[:cache]
          backend_class.include(BackendMethods) unless backend_class.apply_plugin(:cache)
          CacheResetter.apply(model_class, names)
        end
      end

      module BackendMethods
        def read(locale, **options)
          return super(locale, **options) if options.delete(:cache) == false
          if cache.key?(locale)
            cache[locale]
          else
            cache[locale] = super(locale, **options)
          end
        end

        def write(locale, value, **options)
          return super if options.delete(:cache) == false
          cache[locale] = super
        end

        def clear_cache
          @cache = {}
        end

        private

        def cache
          @cache ||= {}
        end
      end

      class CacheResetter < Module
        def self.apply(klass, names)
          methods = []
          if klass < ::ActiveRecord::Base
            methods = [:changes_applied, :clear_changes_information, :reload]
          elsif klass <= ::ActiveModel::Dirty
            methods = [:changes_applied, :clear_changes_information]
          end

          resetter = new do
            methods.each do |method|
              define_method method do |*args|
                super(*args).tap do
                  names.each { |name| translation_backends[name].clear_cache }
                end
              end
            end
          end
          klass.include resetter
        end
      end
    end
  end
end
