# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Errors
        class ErrorTest < DataCycleCore::V4::Base
          # TODO: add more test for invalid values (classifications, Date, ...)
          test 'api/v4/things with invalid parameter (empty value)' do
            params = {
              fields: ''
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json')
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
            assert_equal(response.content_type, 'application/json')
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
            assert_equal(response.content_type, 'application/json')
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
              my_field: 'test_field'
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'my_field'
              },
              'title' => 'Unknown Query Parameter',
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
            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[classifica2tions]'
              },
              'title' => 'Unknown Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)

            params = {
              filter: {
                attribute: {
                  createdAt: {
                    in: {
                      asdf: '2020-5/5'
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_response :bad_request
            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute][createdAt][in][asdf]'
              },
              'title' => 'Unknown Query Parameter',
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
            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[linked][contentLocation][attribute][mod2ifiedAt][in][min]'
              },
              'title' => 'Unknown Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)

            # invalid value
            params = {
              filter: {
                linked: {
                  contentLocation: {
                    attribute: {
                      modifiedAt: {
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
            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[linked][contentLocation][attribute][modifiedAt][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be a string'
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
                          modifiedAt: {
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
            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[linked][contentLocation][linked][image][attribute][modifiedAt][in][min]'
              },
              'title' => 'Unknown Query Parameter',
              'detail' => 'is not allowed'
            }
            assert_equal(error_object, json_data.dig('errors').first)
          end
        end
      end
    end
  end
end
