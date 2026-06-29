# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Regression coverage for the intermittent RespondToMismatchError /
  # DoubleRenderError seen in the API controllers: `log_request_activity` runs in
  # an `after_action`, i.e. *after* the response has already been rendered, so a
  # failing activity-log write must never propagate — otherwise it is re-handled
  # by `rescue_from`, which tries to render/respond a second time and blows up.
  class UserLogRequestActivityTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
    end

    def request_double
      struct_double(params: {}, format: 'pbf', referer: nil, origin: nil, headers: {})
    end

    test 'persists an activity on the happy path' do
      activity = nil

      assert_difference -> { @user.activities.count }, 1 do
        activity = @user.log_request_activity(type: 'mvt_v1_test', data: {}, request: request_double)
      end

      assert_kind_of DataCycleCore::Activity, activity
      assert_predicate activity, :persisted?
      assert_equal 'mvt_v1_test', activity.activity_type
    end

    test 'swallows write failures and logs instead of raising' do
      failing_activities = Object.new
      def failing_activities.create(*_args, **_kwargs)
        raise ActiveRecord::StatementInvalid, 'simulated activity write failure'
      end

      logged = []

      Rails.logger.stub(:error, ->(*args) { logged.concat(args) }) do
        @user.stub(:transaction, ->(*_args, **_kwargs, &block) { block&.call }) do
          @user.stub(:activities, failing_activities) do
            assert_nothing_raised do
              assert_nil @user.log_request_activity(type: 'mvt_v1_test', data: {}, request: request_double)
            end
          end
        end
      end

      assert(logged.any? { |message| message.to_s.include?('log_request_activity') }, 'expected the swallowed error to be logged')
    end
  end
end
