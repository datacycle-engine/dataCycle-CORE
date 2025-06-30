# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OpeningTimeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'handle CET to CEST correctly' do
      schedule = DataCycleCore::Schedule.new.from_hash({
        start_time: { time: '2025-03-30T00:00:00+01:00', zone: 'Europe/Vienna' },
        duration: 'PT23H59M'
      })

      assert_equal(ActiveSupport::Duration.parse('PT23H59M'), schedule.duration)
      hash = schedule.to_opening_hours_specification_schema_org&.first

      assert_equal('2025-03-30', hash['validFrom'])
      assert_equal('00:00', hash['opens'])
      assert_equal('23:59', hash['closes'])
    end

    test 'handle CEST to CET correctly' do
      schedule = DataCycleCore::Schedule.new.from_hash({
        start_time: { time: '2025-10-26T00:00:00+02:00', zone: 'Europe/Vienna' },
        duration: 'PT23H59M'
      })

      assert_equal(ActiveSupport::Duration.parse('PT23H59M'), schedule.duration)
      hash = schedule.to_opening_hours_specification_schema_org&.first

      assert_equal('2025-10-26', hash['validFrom'])
      assert_equal('00:00', hash['opens'])
      assert_equal('23:59', hash['closes'])
    end
  end
end
