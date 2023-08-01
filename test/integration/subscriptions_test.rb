# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SubscriptionsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      DataCycleCore::Thing.delete_all
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
    end

    setup do
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'subscribe article' do
      post create_subscriptions_path, xhr: true, params: {
        subscribable_id: @content.id,
        subscribable_type: @content.class.name
      }, headers: {
        referer: thing_path(@content)
      }

      assert_response :success

      get subscriptions_path
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'

      @content.set_data_hash(data_hash: {
        name: 'TestArtikel123'
      }, partial_update: true)
    end

    test 'unsubscribe article' do
      user = User.find_by(email: 'admin@datacycle.at')
      sign_in(user)

      DataCycleCore::Subscription.find_or_create_by(subscribable_id: @content.id, subscribable_type: @content.class.name, user_id: user.id)

      get subscriptions_path
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'

      subscription = @content.subscriptions.find_by(user_id: user.id)

      delete subscription_path(subscription), xhr: true, params: {}, headers: {
        referer: thing_path(@content)
      }

      assert_response :success

      get subscriptions_path
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestArtikel' }
    end
  end
end
