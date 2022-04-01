# frozen_string_literal: true

require 'translations/backends/active_record'
require 'translations/backends/hash_valued'

module Translations
  module Backends
    module ActiveRecord
      class PgHash
        include Translations::Backends::ActiveRecord
        include Translations::Backends::HashValued

        def each_locale
          super { |l| yield l.to_sym }
        end

        def translations
          model.read_attribute(column_name)
        end

        setup do |attributes, options = {}|
          attributes.each { |attribute| store (options[:column_affix] % attribute), coder: Coder }
        end

        class Coder
          def self.dump(obj)
            raise ArgumentError, "Attribute is supposed to be a Hash, but was a #{obj.class}. -- #{obj.inspect}" unless obj.is_a?(::Hash) || obj.is_a?(::ActiveSupport::HashWithIndifferentAccess)
            obj.each_with_object({}) do |(locale, value), translations|
              translations[locale] = value if value.present?
            end
          end

          def self.load(obj)
            obj
          end
        end
      end
      private_constant :PgHash
    end
  end
end
