# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Aggregate
        def external_syncs_as_property_values
          return super unless aggregate_type_aggregate?

          send(MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME).flat_map(&:external_syncs_as_property_values).uniq
        end

        def icon_type
          return super unless aggregate_type_aggregate?

          icon_type = super
          base_type = icon_type.gsub("_#{MasterData::Templates::AggregateTemplate::AGGREGATE_TEMPLATE_SUFFIX.underscore_blanks}", '')

          "#{icon_type} #{base_type}"
        end
      end
    end
  end
end
