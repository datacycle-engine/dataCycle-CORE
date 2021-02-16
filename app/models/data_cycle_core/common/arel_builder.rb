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

      def get_dict(column)
        Arel::Nodes::NamedFunction.new('get_dict', [column])
      end
    end
  end
end
