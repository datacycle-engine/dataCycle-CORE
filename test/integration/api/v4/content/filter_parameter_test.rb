# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class FilterParameterTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @content = DataCycleCore::DummyDataHelper.create_data('poi')
          @content.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@content.longitude, @content.latitude)
          @content.save
          @event = DataCycleCore::DummyDataHelper.create_data('event')
          schedule = DataCycleCore::TestPreparations.generate_schedule(8.days.ago.midday, 8.days.from_now, 1.hour).serialize_schedule_object
          @event.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: schedule.dtstart, end_date: schedule.dtend }, event_schedule: [schedule.schedule_object.to_hash] })

          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'parameter q for fulltext_search with empty string --> all' do
          get api_v4_things_path(filter: { search: '' })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(3, json_data['@graph'].size)
          assert_equal(3, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'parameter q for fulltext_search multiple hits' do
          get api_v4_things_path(filter: { search: 'Headline' })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(2, json_data['@graph'].size)
          assert_equal(2, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        # disabled test after removed classification from full text search
        # test 'parameter q for fulltext_search one hit' do
        #   get api_v4_things_path(filter: { search: 'Montag' })
        #   assert_response :success
        #
        #   assert_equal(response.content_type, 'application/json')
        #   json_data = JSON.parse(response.body)
        #   assert_equal(1, json_data['@graph'].size)
        #   assert_equal(1, json_data['meta']['total'].to_i)
        #   assert_equal(true, json_data['links'].present?)
        # end

        test 'parameter filter[:box] for geo-queries' do
          get api_v4_things_path(filter: { box: '0,0,10,10' })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'parameter filter[:from, :to] for event queries' do
          get api_v4_things_path(filter: { from: '01-01-2000', to: '31-12-2030' })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'parameter filter[:from] for event queries' do
          get api_v4_things_path(filter: { from: '01-01-2000' })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'parameter filter[:to] for event queries' do
          get api_v4_things_path(filter: { to: (@event.end_date - 7.days).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)

          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end
      end
    end
  end
end
