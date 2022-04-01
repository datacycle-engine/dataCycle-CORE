# frozen_string_literal: true

module Translations
  module Arel
    module TranslationExpressions
      include ::Arel::Expressions

      # @note This is necessary in order to ensure that when a translated
      #   attribute is selected with an alias using +AS+, the resulting
      #   expression can still be counted without blowing up.
      #
      #   Extending +::Arel::Expressions+ is necessary to convince ActiveRecord
      #   that this node should not be stringified, which otherwise would
      #   result in garbage SQL.
      #
      # @see https://github.com/rails/rails/blob/847342c25c61acaea988430dc3ab66a82e3ed486/activerecord/lib/active_record/relation/calculations.rb#L261
      def as(*)
        super
          .extend(::Arel::Expressions)
          .extend(Countable)
      end

      module Countable
        def count(*args)
          left.count(*args)
        end
      end
    end
  end
end
