# frozen-string-literal: true

module DataCycleCore
  module Translation
    module Arel
      module Nodes
        [
          'JsonDashArrow',
          'JsonDashDoubleArrow',
          'JsonbDashArrow',
          'JsonbDashDoubleArrow',
          'JsonbQuestion'
        ].each do |name|
          const_set name, (Class.new(Binary) do
            include ::Arel::Predications
            include ::Arel::OrderPredications
            include ::Arel::AliasPredication
            include DataCycleCore::Translation::Arel::TranslationExpressions

            def lower
              super self
            end
          end)
        end

        class Jsonb
          def to_dash_arrow
            JsonbDashArrow.new left, right
          end

          def to_question
            JsonbQuestion.new left, right
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

        class JsonbContainer < Jsonb
          def initialize(column, locale, attr)
            @column = column
            @locale = locale
            super(JsonbDashArrow.new(column, locale), attr)
          end

          def eq(other)
            other.nil? ? super.or(JsonbQuestion.new(@column, @locale).not) : super
          end
        end
      end

      module Visitors
        def visit_Translation_Arel_Nodes_JsonDashArrow(o, a)
          json_infix o, a, '->'
        end

        def visit_Translation_Arel_Nodes_JsonDashDoubleArrow(o, a)
          json_infix o, a, '->>'
        end

        def visit_Translation_Arel_Nodes_JsonbDashArrow(o, a)
          json_infix o, a, '->'
        end

        def visit_Translation_Arel_Nodes_JsonbDashDoubleArrow(o, a)
          json_infix o, a, '->>'
        end

        def visit_Translation_Arel_Nodes_JsonbQuestion(o, a)
          json_infix o, a, '?'
        end

        private

        def json_infix(o, a, opr)
          visit(Nodes::Grouping.new(::Arel::Nodes::InfixOperation.new(opr, o.left, o.right)), a)
        end
      end

      ::Arel::Visitors::PostgreSQL.include Visitors
    end
  end
end
