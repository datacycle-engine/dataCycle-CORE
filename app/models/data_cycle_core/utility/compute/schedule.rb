# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Schedule
        class << self
          def start_date(computed_parameters:, **_args)
            Array.wrap(computed_parameters.values.first&.map { |e| DataCycleCore::Schedule.new.from_hash(e)&.dtstart }).compact.min
          end

          def end_date(computed_parameters:, **_args)
            end_dates = Array.wrap(computed_parameters.values.first&.map { |e| DataCycleCore::Schedule.new.from_hash(e)&.dtend })

            return if nil.in?(end_dates)

            end_dates.compact.max
          end
        end
      end
    end
  end
end
