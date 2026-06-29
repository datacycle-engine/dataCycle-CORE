# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class ForecastTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def wind_direction(degree)
          DataCycleCore::Utility::Compute::Forecast.wind_direction(computed_parameters: { 'wind_direction' => degree })
        end

        test 'returns nil for a blank wind direction' do
          assert_nil(wind_direction(nil))
        end

        test 'maps every compass sector to its abbreviation' do
          expected = {
            0 => 'N', 22 => 'NNE', 45 => 'NE', 67 => 'ENE', 90 => 'E',
            112 => 'ESE', 135 => 'SE', 157 => 'SSE', 180 => 'S', 202 => 'SSW',
            225 => 'SW', 247 => 'WSW', 270 => 'W', 292 => 'WNW', 315 => 'NW', 337 => 'NNW'
          }

          expected.each do |degree, direction|
            assert_equal(direction, wind_direction(degree), "expected #{degree}° to map to #{direction}")
          end
        end

        test 'wraps degrees outside 0..360 via modulo' do
          assert_equal('N', wind_direction(360))
          assert_equal('N', wind_direction(720))
          assert_equal('N', wind_direction(-10))
          assert_equal('E', wind_direction(450)) # 450 % 360 == 90
        end

        test 'coerces string degrees to float' do
          assert_equal('E', wind_direction('90'))
        end
      end
    end
  end
end
