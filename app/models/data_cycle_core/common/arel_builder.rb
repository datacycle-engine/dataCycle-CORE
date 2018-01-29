module DataCycleCore::Common::ArelBuilder
  def absolute_date_diff(field1, field2, precision: 'day')
    Arel::Nodes::NamedFunction.new(
      'ABS',
      [Arel::Nodes::NamedFunction.new(
        'DATE_PART',
        [
          Arel::Nodes.build_quoted(precision),
          Arel::Nodes::Subtraction.new(field1, field2)
        ]
      )]
    )
  end
end
