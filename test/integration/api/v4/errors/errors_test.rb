# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Errors
        class ErrorTest < DataCycleCore::V4::Base
          before(:all) do
            @content = DataCycleCore::V4::DummyDataHelper.create_data('article')
            @content.set_data_hash(partial_update: true, prevent_history: true, data_hash: { validity_period: { 'valid_from' => 10.days.ago.to_date, 'valid_until' => 5.days.ago.to_date } })
          end

          # TODO: add more test for invalid values (classifications, Date, ...)
          test 'api/v4/things with invalid parameter (empty value)' do
            params = {
              fields: ''
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'fields'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be filled'
            }
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'api/v4/things with invalid parameters (invalid values)' do
            params = {
              page: {
                size: 'asdf'
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'page[size]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be an integer'
            }
            assert_equal(error_object, json_data.dig('errors').first)

            params = {
              page: {
                size: -1
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'page[size]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be greater than or equal to 1'
            }
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'api/v4/things with unknown parameter' do
            params = {
              filter: {
                my_field: 'test_field'
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[my_field]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)

            params = {
              filter: {
                classifica2tions: 'asdf'
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[classifica2tions]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)

            params = {
              filter: {
                attribute: {
                  'dct:created': {
                    in: {
                      asdf: '2020-5/5'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute][dct:created][in][asdf]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'api/v4/things with invalid linked filter parameters' do
            # invalid parameter
            params = {
              filter: {
                linked: {
                  contentLocation: {
                    attribute: {
                      mod2ifiedAt: {
                        in: {
                          min: '2020-07-07'
                        }
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[linked][contentLocation][attribute][mod2ifiedAt][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)

            # invalid value
            params = {
              filter: {
                linked: {
                  contentLocation: {
                    attribute: {
                      'dct:modified': {
                        in: {
                          min: ['asdf']
                        }
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[linked][contentLocation][attribute][dct:modified][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be a string or must be an integer or must be a float'
            }
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'api/v4/things test multiple nested linked filter are not possible' do
            # invalid parameter
            params = {
              filter: {
                linked: {
                  contentLocation: {
                    linked: {
                      image: {
                        attribute: {
                          'dct:modified': {
                            in: {
                              min: '2020-07-07'
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[linked][contentLocation][linked][image][attribute][dct:modified][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'api/v4/things detail error for expired items' do
            params = {
              id: @content.id
            }
            post api_v4_thing_path(params)
            assert_response :not_found
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'pointer' => request.path
              },
              'title' => 'Content is expired',
              'detail' => 'is expired'
            }
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'api/v4/things detail error for random uuid items' do
            params = {
              id: SecureRandom.uuid
            }
            get api_v4_thing_path(params)
            error_object = {
              'source' => {
                'pointer' => request.path
              },
              'detail' => 'Not found'
            }
            assert_response :not_found
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)

            post api_v4_thing_path(params)
            assert_response :not_found
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'GET/POST /api/v4/endpoints/:uuid/ with random :uuid responds with 404' do
            params = {
              id: SecureRandom.uuid
            }

            get api_v4_stored_filter_path(params)
            error_object = {
              'source' => {
                'pointer' => request.path
              },
              'detail' => 'Not found'
            }
            assert_response :not_found
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)

            post api_v4_stored_filter_path(params)
            assert_response :not_found
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'GET/POST /api/v4/collections/:uuid with random :uuid responds with 404' do
            params = {
              id: SecureRandom.uuid
            }

            get api_v4_collection_path(params)
            follow_redirect!
            error_object = {
              'source' => {
                'pointer' => request.path
              },
              'detail' => 'Not found'
            }
            assert_response :not_found
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)

            post api_v4_collection_path(params)
            follow_redirect!
            assert_response :not_found
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)
          end

          test 'GET/POST /api/v4/collections/:uuid without token' do
            sign_out(User.find_by(email: 'tester@datacycle.at'))
            params = {
              id: SecureRandom.uuid
            }

            get api_v4_collection_path(params)
            error_object = {
              'source' => {
                'pointer' => request.env&.dig('warden.options', :attempted_path)
              },
              'detail' => 'invalid or missing authentication token'
            }
            assert_response :unauthorized
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)

            post api_v4_collection_path(params)
            assert_response :unauthorized
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data.dig('errors').first)
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end
        end
      end
    end
  end
end
