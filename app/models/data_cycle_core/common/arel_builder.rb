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

      def tsquery(string)
        Arel::Nodes::NamedFunction.new('plainto_tsquery', [quoted('simple'), string])
      end
    end
  end
end
