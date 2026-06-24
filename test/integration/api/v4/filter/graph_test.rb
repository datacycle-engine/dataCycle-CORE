# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GraphTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all

            @cc0 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC0').first
            @cc_by = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY').first
            @cc_by_nd = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY-ND').first

            @event_data_type = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Veranstaltung').first
            @image_data_type = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Bild').first
            @poi_data_type = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('POI').first

            @image1 = create_test_image(@cc0)
            @image2 = create_test_image(@cc0)
            @image3 = create_test_image(@cc0)
            @image4 = create_test_image(@cc_by)
            @image5 = create_test_image(@cc_by)
            @image6 = create_test_image(@cc_by_nd)
            @image7 = create_test_image(nil)

            @poi1 = create_test_poi(nil, [@image1.id, @image2.id, @image4.id])
            @poi2 = create_test_poi(nil, [@image2.id])
            @poi3 = create_test_poi(nil, [@image3.id])
            @poi4 = create_test_poi(nil, [])
            @poi5 = create_test_poi(nil, [@image5.id])
            @poi6 = create_test_poi(nil, [@image6.id])
            @poi7 = create_test_poi(@cc_by, [@image7.id])

            @event_a = create_test_event(nil, @poi6.id, [@image7.id])

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          def create_test_image(license_classification)
            image = DataCycleCore::V4::DummyDataHelper.create_data('image')
            image.set_data_hash(partial_update: true, prevent_history: true, data_hash: { license_classification: [license_classification&.primary_classification&.id] })

            image
          end

          def create_test_event(license_classification, poi_id, image_ids)
            event = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            event.set_data_hash(partial_update: true, prevent_history: true, data_hash: {
              license_classification: [license_classification&.primary_classification&.id],
              image: Array.wrap(image_ids),
              content_location: Array.wrap(poi_id)
            })

            event
          end

          def create_test_poi(license_classification, image_ids)
            poi = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: {
              license_classification: [license_classification&.primary_classification&.id],
              image: Array.wrap(image_ids)
            })

            poi
          end

          test 'api/v4/things parameter filter[:graph]' do
            # all pois with images
            expected = [@poi1, @poi2, @poi3, @poi7, @poi5, @poi6]

            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                },
                graph: {
                  photo: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id]
                      }
                    }
                  }
                }
              }
            }

            post api_v4_things_path(params)

            assert_api_count_result(6)

            json_data = response.parsed_body

            assert_equal(expected.pluck('id').sort, json_data['@graph'].pluck('@id').sort)

            # all pois with images (with classification cc0)
            expected = [@poi1, @poi2, @poi3]

            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                },
                graph: {
                  photo: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id, @cc0.id]
                      }
                    }
                  }
                }
              }
            }

            post api_v4_things_path(params)

            assert_api_count_result(3)

            json_data = response.parsed_body

            assert_equal(expected.pluck('id').sort, json_data['@graph'].pluck('@id').sort)

            # all pois with images (license cc_by)
            expected = [@poi1, @poi5]
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                },
                graph: {
                  photo: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id, @cc_by.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)

            json_data = response.parsed_body

            assert_api_count_result(2)
            assert_equal(expected.pluck('id').sort, json_data['@graph'].pluck('@id').sort)
          end

          # unknown attribute to trigger BadRequest
          test 'api/v4/things unknown attribute_name' do
            params = {
              filter: {
                graph: {
                  unknown_attr: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id, @cc_by.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)

            assert_response :bad_request

            params = {
              filter: {
                graph: {
                  location: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id, @cc_by.id]
                      }
                    }
                  },
                  unknown_attr: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id, @cc_by.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)

            assert_response :bad_request

            params = {
              filter: {
                graph: {
                  unknown_attr1: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id, @cc_by.id]
                      }
                    }
                  },
                  unknown_attr2: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id, @cc_by.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)

            assert_response :bad_request
          end

          # property_name and api_name - to contain "old" functionality
          test 'api/v4/things filter[:graph] with property name or api name' do
            expected = [@poi1, @poi2, @poi3, @poi5, @poi6, @poi7]

            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                },
                graph: {
                  photo: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id]
                      }
                    }
                  }
                }
              }
            }

            post api_v4_things_path(params)
            json_data = response.parsed_body

            assert_api_count_result(6)
            assert_equal(expected.pluck('id').sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                },
                graph: {
                  image: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id]
                      }
                    }
                  }
                }
              }
            }

            post api_v4_things_path(params)
            json_data = response.parsed_body

            assert_api_count_result(6)
            assert_equal(expected.pluck('id').sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/things filter[:graph] with multiple attributes' do
            expected = [@poi1, @poi2, @poi3, @poi5, @poi6, @poi7]
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                },
                graph: {
                  image: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id]
                      }
                    }
                  },
                  photo: {
                    classifications: {
                      in: {
                        withSubtree: [@image_data_type.id]
                      }
                    }
                  }
                }
              }
            }

            post api_v4_things_path(params)
            json_data = response.parsed_body

            assert_api_count_result(6)
            assert_equal(expected.pluck('id').sort, json_data['@graph'].pluck('@id').sort)
          end
        end
      end
    end
  end
end
