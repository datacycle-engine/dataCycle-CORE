# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class LinkedTest < DataCycleCore::V4::Base
          # setup description
          # 4 events
          ## 8.days.ago - 5.days.ago
          ## 5.days.ago - 5.days
          ## today - tomorrow
          ## 5.days - 10.days
          # 4 places (long lat)
          ## 10 1
          ## 5 5
          ## 1 10
          ## 1 1
          # 4 images
          ## 2 iamges: cc0
          ## 2 images: ccby

          before(:all) do
            DataCycleCore::Thing.delete_all

            @cc0 = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC0').first
            @cc_by = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name('CC BY').first

            @event_data_type = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Veranstaltung').first
            @image_data_type = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('Bild').first
            @poi_data_type = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').with_name('POI').first

            schedule_a = DataCycleCore::TestPreparations.generate_schedule(8.days.ago.midday, 5.days.ago, 1.hour).serialize_schedule_object
            lat_long_a = {
              'latitude': 1,
              'longitude': 10
            }
            @event_a = create_test_event(schedule_a, @cc_by.primary_classification.id, lat_long_a)

            schedule_b = DataCycleCore::TestPreparations.generate_schedule(5.days.ago.midday, 5.days.from_now, 1.hour).serialize_schedule_object
            lat_long_b = {
              'latitude': 5,
              'longitude': 5
            }
            @event_b = create_test_event(schedule_b, @cc0.primary_classification.id, lat_long_b)

            schedule_c = DataCycleCore::TestPreparations.generate_schedule(Time.zone.now.beginning_of_day, 1.day.from_now, 1.hour).serialize_schedule_object
            lat_long_c = {
              'latitude': 10,
              'longitude': 1
            }
            @event_c = create_test_event(schedule_c, @cc0.primary_classification.id, lat_long_c)

            schedule_d = DataCycleCore::TestPreparations.generate_schedule(5.days.from_now.midday, 10.days.from_now, 1.hour).serialize_schedule_object
            lat_long_d = {
              'latitude': 1,
              'longitude': 1
            }
            @event_d = create_test_event(schedule_d, @cc_by.primary_classification.id, lat_long_d)

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          test 'api/v4/things parameter filter[:linked]' do
            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            # all events
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            # all images
            # poi: 4 images
            # events: 4 images
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @image_data_type.id
                    ]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(8)

            # all pois
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            # all pois with box filter
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @poi_data_type.id
                    ]
                  }
                },
                geo: {
                  in: {
                    box: ['1', '3', '7', '12']
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            # all events with box
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                },
                linked: {
                  content_location: {
                    geo: {
                      in: {
                        box: ['1', '3', '7', '12']
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            json_data['@graph'].each do |res|
              assert('Event', res.dig('@type'))
            end

            # all images with cc0
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @image_data_type.id,
                      @cc0.id
                    ]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(6)

            # all events with images + license cc0
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                },
                linked: {
                  image: {
                    classifications: {
                      in: {
                        withSubtree: [@cc0.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            json_data['@graph'].each do |res|
              assert('Event', res.dig('@type'))
            end

            # events
            # with image cc_by
            # in box
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                },
                linked: {
                  content_location: {
                    geo: {
                      in: {
                        box: ['1', '3', '7', '12']
                      }
                    }
                  },
                  image: {
                    classifications: {
                      in: {
                        withSubtree: [@cc_by.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(0)

            json_data = response.parsed_body
            json_data['@graph'].each do |res|
              assert('Event', res.dig('@type'))
            end

            # events
            # with image cc0
            # in box
            params = {
              filter: {
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                },
                linked: {
                  content_location: {
                    geo: {
                      in: {
                        box: ['1', '3', '7', '12']
                      }
                    }
                  },
                  image: {
                    classifications: {
                      in: {
                        withSubtree: [@cc0.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            json_data['@graph'].each do |res|
              assert('Event', res.dig('@type'))
            end

            # events from today
            # with image cc0
            # in box
            params = {
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_day.to_fs(:iso8601)
                    }
                  }
                },
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                },
                linked: {
                  content_location: {
                    geo: {
                      in: {
                        box: ['1', '3', '7', '12']
                      }
                    }
                  },
                  image: {
                    classifications: {
                      in: {
                        withSubtree: [@cc0.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            json_data['@graph'].each do |res|
              assert('Event', res.dig('@type'))
            end

            # events start in 2days today
            # with image cc0
            # in box
            params = {
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: 2.days.from_now.to_fs(:iso8601)
                    }
                  }
                },
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                },
                linked: {
                  content_location: {
                    geo: {
                      in: {
                        box: ['1', '3', '7', '12']
                      }
                    }
                  },
                  image: {
                    classifications: {
                      in: {
                        withSubtree: [@cc0.id]
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            json_data = response.parsed_body
            assert_equal(@event_b.id, json_data['@graph'].first.dig('@id'))

            # validate linked with 'dct:modified'
            image_test = @event_c.image.first
            orig_ts = image_test.updated_at
            image_test.update_column(:updated_at, (Time.zone.now + 10.days))

            # events start in 2days today
            # with image cc0
            # in box
            params = {
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: 15.days.ago.to_fs(:iso8601)
                    }
                  }
                },
                classifications: {
                  in: {
                    withSubtree: [
                      @event_data_type.id
                    ]
                  }
                },
                linked: {
                  image: {
                    attribute: {
                      'dct:modified': {
                        in: {
                          min: (Time.zone.now + 5.days).to_fs(:iso8601)
                        }
                      }
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            json_data = response.parsed_body
            assert_equal(@event_c.id, json_data['@graph'].first.dig('@id'))
            image_test.update_column(:updated_at, orig_ts)
          end

          def create_test_event(schedule, classification_id, lat_long)
            event = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            image = DataCycleCore::V4::DummyDataHelper.create_data('image')
            image.set_data_hash(partial_update: true, prevent_history: true, data_hash: { license_classification: [classification_id] })
            poi = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long)
            poi.location = RGeo::Geographic.spherical_factory(srid: 4326).point(poi.longitude, poi.latitude)
            poi.save

            event.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                event_schedule: [schedule.schedule_object.to_hash],
                image: [image.id],
                content_location: [poi.id]
              })
            event
          end
        end
      end
    end
  end
end
