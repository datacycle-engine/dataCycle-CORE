# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SubscriptionsTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      DataCycleCore::TestPreparations.create_contents
      DataCycleCore::TestPreparations.create_subscription
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'subscribe article' do
      content = DataCycleCore::CreativeWork.find_by(headline: 'TestArtikel')

      post subscriptions_path, xhr: true, params: {
        subscribable_id: content.id,
        subscribable_type: content.class.name
      }, headers: {
        referer: creative_work_path(content)
      }

      assert_response :success

      get subscriptions_path
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'
    end

    test 'unsubscribe article' do
      user = User.find_by(email: 'admin@datacycle.at')
      sign_in(user)
      content = DataCycleCore::CreativeWork.find_by(headline: 'TestArtikel')

      get subscriptions_path
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'

      subscription = content.subscriptions.find_by(user_id: user.id)

      delete subscription_path(subscription), xhr: true, params: {}, headers: {
        referer: creative_work_path(content)
      }

      assert_response :success

      get subscriptions_path
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestArtikel' }
    end
  end
end
