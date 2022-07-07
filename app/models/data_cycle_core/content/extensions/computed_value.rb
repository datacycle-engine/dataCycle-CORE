# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module ComputedValue
        def add_computed_values(data_hash:)
          computed_property_names.each do |computed_property|
            DataCycleCore::Utility::Compute::Base.compute_values(computed_property, data_hash, self)
          end
        end
      end
    end
  end
end
