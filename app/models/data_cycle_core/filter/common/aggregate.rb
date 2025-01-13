# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Aggregate
        def aggregate_filter(value = nil)
          return self if value.blank?

          reflect(
            @query.where(thing_alias[:aggregate_type].in(value))
          )
        end

        def not_aggregate_filter(value = nil)
          return self if value.blank?

          reflect(
            @query.where.not(thing_alias[:aggregate_type].in(value))
          )
        end
      end
    end
  end
end
