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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'fields'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be filled'
            }

            assert_equal(error_object, json_data['errors'].first)
          end

          test 'api/v4/things with invalid parameters (invalid values)' do
            params = {
              page: {
                size: 'asdf'
              }
            }
            post api_v4_things_path(params)

            assert_response :bad_request
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'page[size]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be an integer'
            }

            assert_equal(error_object, json_data['errors'].first)

            params = {
              page: {
                size: -1
              }
            }
            post api_v4_things_path(params)

            assert_response :bad_request
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'page[size]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be greater than or equal to 1'
            }

            assert_equal(error_object, json_data['errors'].first)
          end

          test 'api/v4/things with unknown parameter' do
            params = {
              filter: {
                my_field: 'test_field'
              }
            }
            post api_v4_things_path(params)

            assert_response :bad_request
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[my_field]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }

            assert_equal(error_object, json_data['errors'].first)

            params = {
              filter: {
                classifica2tions: 'asdf'
              }
            }
            post api_v4_things_path(params)

            assert_response :bad_request
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[classifica2tions]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }

            assert_equal(error_object, json_data['errors'].first)

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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute][dct:created][in][asdf]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }

            assert_equal(error_object, json_data['errors'].first)
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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute][mod2ifiedAt]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'attribute is unknown'
            }

            assert_equal(error_object, json_data['errors'].first)

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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[linked][contentLocation][attribute][dct:modified][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be a string or must be an integer or must be a float'
            }

            assert_equal(error_object, json_data['errors'].first)
          end

          test 'api/v4/things test multiple nested linked filter are possible' do
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

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(4, json_data.size)
            assert_nil(json_data['errors'])
          end

          test 'api/v4/things test linked nested in graph filter are possible' do
            # invalid parameter
            params = {
              filter: {
                linked: {
                  contentLocation: {
                    graph: {
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

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(4, json_data.size)
            assert_nil(json_data['errors'])
          end

          test 'api/v4/things test graph nested in linked filter is possible' do
            # invalid parameter
            params = {
              filter: {
                graph: {
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

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(4, json_data.size)
            assert_nil(json_data['errors'])
          end

          test 'api/v4/things test graph nested in graph filter ist possible' do
            # invalid parameter
            params = {
              filter: {
                graph: {
                  contentLocation: {
                    graph: {
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

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(4, json_data.size)
            assert_nil(json_data['errors'])
          end

          test 'api/v4/things test linked/attribute/graph nested in attribute filter are not possible' do
            # invalid parameter
            params = {
              filter: {
                attribute: {
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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute][contentLocation][linked][image][attribute][dct:modified][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }

            assert_equal(error_object, json_data['errors'].first)

            # invalid parameter
            params = {
              filter: {
                attribute: {
                  contentLocation: {
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
            post api_v4_things_path(params)

            assert_response :bad_request
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute][contentLocation][attribute][dct:modified][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }

            assert_equal(error_object, json_data['errors'].first)

            # invalid parameter
            params = {
              filter: {
                attribute: {
                  contentLocation: {
                    graph: {
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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute][contentLocation][graph][image][attribute][dct:modified][in][min]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'is not allowed'
            }

            assert_equal(error_object, json_data['errors'].first)
          end

          # Nothing constrains the shape of a request parameter, so a scalar can land where
          # ApiService#validate_api_filters walks a hash or an array. Every row below answered with a
          # 500 before it reported a bad request: the wrapper rows raised NoMethodError on String#each,
          # the nested ones the bare RuntimeError that guarded the recursion.
          test 'api/v4/things with wrongly shaped filter wrappers responds with bad request' do
            [
              [{ attribute: 'x' }, 'filter[attribute]', 'must be a hash'],
              [{ graph: 'x' }, 'filter[graph]', 'must be a hash'],
              [{ linked: 'x' }, 'filter[linked]', 'must be a hash'],
              [{ attribute: { 'dct:modified': 'x' } }, 'filter[attribute][dct:modified]', 'must be a hash'],
              [{ linked: { contentLocation: 'x' } }, 'filter[linked][contentLocation]', 'must be a hash'],
              [{ union: 'x' }, 'filter[union]', 'must be an array'],
              [{ union: { contentId: { in: ['x'] } } }, 'filter[union]', 'must be an array'],
              [{ union: ['x'] }, 'filter[union][0]', 'must be a hash']
            ].each do |filter, parameter, detail|
              post api_v4_things_path(filter: filter)

              assert_response :bad_request
              assert_equal('application/json; charset=utf-8', response.content_type)
              json_data = response.parsed_body

              assert_equal(1, json_data.size)
              assert_equal(1, json_data['errors'].size)
              error_object = {
                'source' => {
                  'parameter' => parameter
                },
                'title' => 'Invalid Query Parameter',
                'detail' => detail
              }

              assert_equal(error_object, json_data['errors'].first)
            end
          end

          # The request from AppSignal incident 188 on the route that reported it. ContentsController
          # validates params in a before_action, i.e. before the endpoint's stored filter is looked
          # up, so a wrongly shaped filter answers 400 even for an :id that does not exist.
          test 'api/v4/endpoints with a scalar attribute filter responds with bad request' do
            get api_v4_stored_filter_path(id: SecureRandom.uuid, filter: { attribute: 'x' }, page: { size: '1' })

            assert_response :bad_request
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'parameter' => 'filter[attribute]'
              },
              'title' => 'Invalid Query Parameter',
              'detail' => 'must be a hash'
            }

            assert_equal(error_object, json_data['errors'].first)
          end

          test 'api/v4/things detail error for expired items' do
            params = {
              id: @content.id
            }
            post api_v4_thing_path(params)

            assert_response :not_found
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            error_object = {
              'source' => {
                'pointer' => request.path
              },
              'title' => 'Content is expired',
              'detail' => 'is expired'
            }

            assert_equal(error_object, json_data['errors'].first)
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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)

            post api_v4_thing_path(params)

            assert_response :not_found
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)
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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)

            post api_v4_stored_filter_path(params)

            assert_response :not_found
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)
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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)

            post api_v4_collection_path(params)
            follow_redirect!

            assert_response :not_found
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)
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
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)

            post api_v4_collection_path(params)

            assert_response :unauthorized
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data = response.parsed_body

            assert_equal(1, json_data.size)
            assert_equal(1, json_data['errors'].size)
            assert_equal(error_object, json_data['errors'].first)
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end
        end
      end
    end
  end
end
