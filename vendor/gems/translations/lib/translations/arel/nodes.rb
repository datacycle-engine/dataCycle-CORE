# frozen_string_literal: true

# require 'translations/arel'
require 'translations/arel/translation_expressions'

module Translations
  module Arel
    module Nodes
      class Binary < ::Arel::Nodes::Binary; end
      class Grouping < ::Arel::Nodes::Grouping; end

      ::Arel::Visitors::ToSql.class_eval do
        alias_method :visit_Translation_Arel_Nodes_Grouping, :visit_Arel_Nodes_Grouping
      end

      [
        'JsonbDashArrow',
        'JsonbDashDoubleArrow',
        'JsonbQuestion'
      ].each do |name|
        const_set name, (Class.new(Binary) do
          include ::Arel::Predications
          include ::Arel::OrderPredications
          include ::Arel::AliasPredication
          include Translations::Arel::TranslationExpressions

          def lower
            super self
          end
        end)
      end
    end
  end
end
