# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the Activity model's reporting class-methods. Each builds a raw-SQL
  # aggregate over the activities table (empty in tests); we just execute every scope
  # to exercise the query construction, the default-range branches and the
  # `&.map&.inject(&:merge)` reductions (which collapse to nil over zero rows).
  class ActivityScopesCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'activity_list returns the distinct activity types' do
      assert_equal [], DataCycleCore::Activity.activity_list
    end

    test 'activity_stats builds the ordered count relation for default and explicit ranges' do
      assert_equal [], DataCycleCore::Activity.activity_stats.to_a
      assert_equal [], DataCycleCore::Activity.activity_stats(1.day.ago, Time.zone.now).to_a
    end

    test 'activities_by_user raises on a blank id and reduces to nil over no rows' do
      assert_raises(ArgumentError) { DataCycleCore::Activity.activities_by_user(nil) }
      assert_nil DataCycleCore::Activity.activities_by_user(SecureRandom.uuid)
    end

    test 'user_doing_activity raises on a blank activity and reduces to nil over no rows' do
      assert_raises(ArgumentError) { DataCycleCore::Activity.user_doing_activity(nil) }
      assert_nil DataCycleCore::Activity.user_doing_activity('api')
    end

    test 'activities_user_overview builds the joined ordered relation' do
      assert_equal [], DataCycleCore::Activity.activities_user_overview.to_a
    end

    test 'activity_details builds the json-extracted grouped relation' do
      assert_equal [], DataCycleCore::Activity.activity_details.to_a
    end

    test 'used_widgets builds the widget grouping relation' do
      assert_equal [], DataCycleCore::Activity.used_widgets.to_a
    end

    test 'activities_by_user and user_doing_activity reduce real rows into a hash' do
      user = DataCycleCore::User.first
      DataCycleCore::Activity.create!(activity_type: 'api_v4', user:, activitiable: user)

      assert_equal 1, DataCycleCore::Activity.activities_by_user(user.id)['api_v4']
      assert_equal 1, DataCycleCore::Activity.user_doing_activity('api_v4')[user.id]
    end
  end
end
