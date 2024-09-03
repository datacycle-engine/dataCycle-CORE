# frozen_string_literal: true

module DataCycleCore
  module Common
    module ArelBuilder
      def absolute_date_diff(field1, field2, precision: 'day')
        Arel::Nodes::NamedFunction.new(
          'ABS',
          [Arel::Nodes::NamedFunction.new(
            'DATE_PART',
            [
              quoted(precision),
              Arel::Nodes::Subtraction.new(field1, field2)
            ]
          )]
        )
      end

      def quoted(string)
        Arel::Nodes.build_quoted(string)
      end

      def tsmatch(tsvector, tsquery)
        Arel::Nodes::InfixOperation.new('@@', tsvector, tsquery)
      end

      def tsquery(string, dict = nil)
        Arel::Nodes::NamedFunction.new('plainto_tsquery', [dict || quoted('simple'), string])
      end

      def to_tsquery(string, dict = nil)
        Arel::Nodes::NamedFunction.new('to_tsquery', [dict || quoted('simple'), string])
      end

      def websearch_to_tsquery(string, dict = nil)
        Arel::Nodes::NamedFunction.new('websearch_to_tsquery', [dict || quoted('simple'), quoted(string)])
      end

      def websearch_to_prefix_tsquery(string, dict = nil)
        Arel::Nodes::NamedFunction.new('websearch_to_prefix_tsquery', [dict || quoted('simple'), quoted(string)])
      end
    end
  end
end
