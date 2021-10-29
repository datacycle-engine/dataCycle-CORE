# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class HolidaysTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      test 'get Holidays for active Year as JSON' do
        get holidays_path, params: {
          year: DateTime.current.year
        }

        assert_equal Holidays.between(Date.civil(DateTime.current.year, 1, 1), Date.civil(DateTime.current.year, 12, 31), Array.wrap(DataCycleCore.holidays_country_code)).as_json, JSON.parse(@response.body)
      end
    end
  end
end
