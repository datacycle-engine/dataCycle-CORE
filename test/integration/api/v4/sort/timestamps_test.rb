# frozen_string_literal: true

require 'test_helper'
require 'json'
# require 'v4/validation/concept'
require 'v4/helpers/dummy_data_helper'
require 'v4/helpers/api_helper'

module DataCycleCore
  module Api
    module V4
      module Sort
        class TimestampsTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers
          include DataCycleCore::V4::ApiHelper
          include DataCycleCore::V4::DummyDataHelper

          setup do
            DataCycleCore::Thing.where(template: false).delete_all
            @routes = Engine.routes

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @food_establishment_a = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
            @food_establishment_b = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')

            @thing_count = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded').count

            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things with parameter sort: created' do
            orig_ts = @food_establishment_a.created_at
            @food_establishment_a.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations

            # DESC
            params = {
              fields: 'dct:modified,dct:created',
              sort: '-created'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime >= b.dig('dct:created').to_datetime)
            end

            # ASC
            params = {
              fields: 'dct:modified,dct:created',
              sort: '+created'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime <= b.dig('dct:created').to_datetime)
            end

            # make sure ASC is default
            params = {
              fields: 'dct:modified,dct:created',
              sort: 'created'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime <= b.dig('dct:created').to_datetime)
            end

            @food_establishment_a.update_column(:created_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/things with parameter sort: modified' do
            orig_ts = @food_establishment_a.updated_at
            @food_establishment_a.update_column(:updated_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations

            # DESC
            params = {
              fields: 'dct:modified,dct:created',
              sort: '-modified'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').first.dig('@id'))
            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime >= b.dig('dct:modified').to_datetime)
            end

            # ASC
            params = {
              fields: 'dct:modified,dct:created',
              sort: '+modified'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime <= b.dig('dct:modified').to_datetime)
            end

            # make sure ASC is default
            params = {
              fields: 'dct:modified,dct:created',
              sort: 'modified'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime <= b.dig('dct:modified').to_datetime)
            end

            # make sure modified ASC is default for empty sort params
            params = {
              fields: 'dct:modified,dct:created'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime <= b.dig('dct:modified').to_datetime)
            end

            @food_establishment_a.update_column(:updated_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/things parameter multiple and invalid sort params' do
            orig_ts = @food_establishment_a.created_at
            @food_establishment_a.update_column(:created_at, (Time.zone.now + 10.days)) # rubocop:disable Rails/SkipsModelValidations

            params = {
              fields: 'dct:modified,dct:created',
              sort: '-created,+modified,+another'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = JSON.parse(response.body)
            assert_equal(@food_establishment_a.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime >= b.dig('dct:created').to_datetime)
            end
            @food_establishment_a.update_column(:created_at, orig_ts) # rubocop:disable Rails/SkipsModelValidations
          end
        end
      end
    end
  end
end
