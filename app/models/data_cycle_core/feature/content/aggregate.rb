# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Aggregate
        def external_syncs_as_property_values
          return super unless aggregate_type_aggregate?

          send(MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME).flat_map(&:external_syncs_as_property_values).uniq
        end
      end
    end
  end
end
