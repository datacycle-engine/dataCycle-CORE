# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class GoogleBusinessTransformationTest < ActiveSupport::TestCase
    test 'it should transform single opening hours for single day correctly' do
      assert_raise Exception do
        data = Generic::GoogleBusiness::Transformations.convert_opening_hours(
          {
            'periods' => [{
              'openDay' => 'MONDAY',
              'openTime' => '09:30',
              'closeDay' => 'MONDAY',
              'closeTime' => '12:45'
            }]
          }
        )
        assert_equal 1, data.count
        assert_equal '09:30', data[0][:opens]
        assert_equal '12:45', data[0][:closes]
        assert_equal 1, data[0][:day_of_week].count
        assert_equal 'Montag', Classification.find(data[0][:day_of_week].first).name
      end
    end

    test 'it should transform single opening hours for multiple days correctly' do
      assert_raise Exception do
        data = Generic::GoogleBusiness::Transformations.convert_opening_hours(
          {
            'periods' => [{
              'openDay' => 'MONDAY',
              'openTime' => '09:30',
              'closeDay' => 'MONDAY',
              'closeTime' => '12:45'
            }, {
              'openDay' => 'TUESDAY',
              'openTime' => '09:30',
              'closeDay' => 'TUESDAY',
              'closeTime' => '12:45'
            }]
          }
        )

        assert_equal 1, data.count
        assert_equal '09:30', data[0][:opens]
        assert_equal '12:45', data[0][:closes]
        assert_equal 2, data[0][:day_of_week].count
        assert_equal ['Montag', 'Dienstag'].sort, Classification.where(id: data[0][:day_of_week]).map(&:name).sort
      end
    end
  end
end
