# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Schedule
        class << self
          def start_date(virtual_parameters:, content:, **_args)
            Array.wrap(content.try(virtual_parameters.first)).map { |e| e&.dtstart }.compact.min
          end

          def end_date(virtual_parameters:, content:, **_args)
            end_dates = Array.wrap(content.try(virtual_parameters.first)).map { |e| e&.dtend }

            return if nil.in?(end_dates)

            end_dates.compact.max
          end
        end
      end
    end
  end
end
