# frozen_string_literal: true

module DataCycleCore
  module ActiveRecordResultExtension
    # calling .to_hash turns all values, including arrays, into strings,
    # while calling .cast_values returns an array without the column keys.
    # This method returns a hash of the results with properly cast values:
    def to_cast_array
      cols = columns
      cast_values.map do |row|
        cols.zip(row).to_h
      end
    end
  end
end

ActiveRecord::Result.include(DataCycleCore::ActiveRecordResultExtension)
