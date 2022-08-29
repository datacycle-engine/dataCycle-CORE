# frozen_string_literal: true

require 'translations/arel'

module Translations
  module Arel
    module Nodes
      class Jsonb < JsonbDashDoubleArrow
        def to_dash_arrow
          JsonbDashArrow.new(left, right)
        end

        def to_question
          JsonbQuestion.new(left, right)
        end

        def eq(other)
          case other
          when NilClass
            to_question.not
          when Integer, Array, ::Hash
            to_dash_arrow.eq other.to_json
          when Jsonb
            to_dash_arrow.eq other.to_dash_arrow
          when JsonbDashArrow
            to_dash_arrow.eq other
          else
            super
          end
        end
      end
    end

    module Visitors
      def visit_Translations_Arel_Nodes_JsonbDashArrow(o, a) # rubocop:disable Naming/MethodName
        json_infix(o, a, '->')
      end

      def visit_Translations_Arel_Nodes_JsonbDashDoubleArrow(o, a) # rubocop:disable Naming/MethodName
        json_infix(o, a, '->>')
      end

      def visit_Translations_Arel_Nodes_JsonbQuestion(o, a) # rubocop:disable Naming/MethodName
        json_infix(o, a, '?')
      end

      private

      def json_infix(o, a, opr)
        visit(Nodes::Grouping.new(::Arel::Nodes::InfixOperation.new(opr, o.left, o.right)), a)
      end
    end

    ::Arel::Visitors::PostgreSQL.include Visitors
  end
end
