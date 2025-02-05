# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Forecast
        class << self
          def wind_direction(computed_parameters:, **_args)
            degree = computed_parameters['wind_direction']
            return nil if degree.nil?
            degree = degree.to_f % 360
            case degree
            when 0..11.25, 348.75..360
              'N'
            when 11.25..33.75
              'NNE'
            when 33.75..56.25
              'NE'
            when 56.25..78.75
              'ENE'
            when 78.75..101.25
              'E'
            when 101.25..123.75
              'ESE'
            when 123.75..146.25
              'SE'
            when 146.25..168.75
              'SSE'
            when 168.75..191.25
              'S'
            when 191.25..213.75
              'SSW'
            when 213.75..236.25
              'SW'
            when 236.25..258.75
              'WSW'
            when 258.75..281.25
              'W'
            when 281.25..303.75
              'WNW'
            when 303.75..326.25
              'NW'
            when 326.25..348.75
              'NNW'
            end
          end
        end
      end
    end
  end
end
