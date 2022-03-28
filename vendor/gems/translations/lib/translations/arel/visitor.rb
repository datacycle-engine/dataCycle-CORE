# frozen-string-literal: true

module Translations
  module Arel
    class Visitor < ::Arel::Visitors::Visitor
      INNER_JOIN = ::Arel::Nodes::InnerJoin
      OUTER_JOIN = ::Arel::Nodes::OuterJoin

      attr_reader :backend_class, :locale

      def initialize(backend_class, locale)
        super()
        @backend_class = backend_class
        @locale = locale
      end

      private

      def visit(object, collector = nil)
        super(object, collector)
      rescue TypeError
        visit_default(object)
      end

      def visit_collection(_objects)
        raise NotImplementedError
      end
      alias visit_Array visit_collection

      # naming dictated by Arel
      def visit_Arel_Nodes_Unary(object) # rubocop:disable Naming/MethodName
        visit(object.expr)
      end

      def visit_Arel_Nodes_Binary(object) # rubocop:disable Naming/MethodName
        visit_collection([object.left, object.right])
      end

      def visit_Arel_Nodes_Function(object) # rubocop:disable Naming/MethodName
        visit_collection(object.expressions)
      end

      def visit_Arel_Nodes_Case(object) # rubocop:disable Naming/MethodName
        visit_collection([object.case, object.conditions, object.default])
      end

      def visit_Arel_Nodes_And(object) # rubocop:disable Naming/MethodName
        visit_Array(object.children)
      end

      def visit_Arel_Nodes_Node(object) # rubocop:disable Naming/MethodName
        visit_default(object)
      end

      def visit_Arel_Attributes_Attribute(object) # rubocop:disable Naming/MethodName
        visit_default(object)
      end

      def visit_default(_object)
        nil
      end
    end
  end
end
