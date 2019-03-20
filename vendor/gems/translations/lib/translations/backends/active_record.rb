# frozen_string_literal: true

module Translations
  module Backends
    module ActiveRecord
      def self.included(backend_class)
        backend_class.include(Translations::Backend)
        backend_class.extend(ClassMethods)
      end

      module ClassMethods
        def [](name, locale)
          build_node(name.to_s, locale)
        end

        def build_node(_attr, _locale)
          raise NotImplementedError
        end

        def apply_scope(relation, _predicate, _locale = I18n.locale, invert: false) # rubocop:disable Lint/UnusedMethodArgument
          relation
        end

        private

        def build_quoted(value)
          ::Arel::Nodes.build_quoted(value)
        end
      end
    end
  end
end
