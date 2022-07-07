# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Schedule
        class << self
          def start_date(computed_parameters:, **_args)
            computed_parameters.values.first&.map { |e| DataCycleCore::Schedule.new.from_hash(e)&.dtstart }&.compact&.sort&.first
          end

          def end_date(computed_parameters:, **_args)
            end_dates = computed_parameters.values.first&.map { |e| DataCycleCore::Schedule.new.from_hash(e)&.dtend }

            return unless end_dates&.exclude?(nil)

            end_dates&.compact&.sort&.last
          end
        end
      end
    end
  end
end
