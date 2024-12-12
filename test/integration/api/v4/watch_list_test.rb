# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class WatchListTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @user = User.find_by(email: 'tester@datacycle.at')
          DataCycleCore::Thing.delete_all
          @routes = Engine.routes
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' }, user: @user)
          @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel2' }, user: @user)
          @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
          DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
        end

        setup do
          sign_in(@user)
        end

        test '/api/v4/endpoints/:uuid with a valid watch_list' do
          get api_v4_stored_filter_path(id: @watch_list.id)

          assert_equal(response.content_type, 'application/json; charset=utf-8')
          json_data = response.parsed_body
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(@watch_list.id, json_data.dig('meta', 'collection', 'id'))
          assert_equal(@watch_list.name, json_data.dig('meta', 'collection', 'name'))
        end

        test '/api/v4/endpoints/:uuid with a valid watch_list slug' do
          get api_v4_stored_filter_path(id: @watch_list.slug)

          assert_equal(response.content_type, 'application/json; charset=utf-8')
          json_data = response.parsed_body
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(@watch_list.id, json_data.dig('meta', 'collection', 'id'))
          assert_equal(@watch_list.name, json_data.dig('meta', 'collection', 'name'))
        end
      end
    end
  end
end
