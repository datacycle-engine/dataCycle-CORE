# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class UnionTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all

            # name: Headline used for event, event_series and poi
            @event = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            image = DataCycleCore::V4::DummyDataHelper.create_data('image')
            @event_poi = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long = {
              latitude: 3,
              longitude: 3
            }
            @event_poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long)
            @event_poi.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@event_poi.longitude, @event_poi.latitude)
            @event_poi.save

            @event.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                image: [image.id],
                content_location: [@event_poi.id]
              })

            @poi = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long = {
              latitude: 5,
              longitude: 5
            }
            @poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long)
            @poi.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi.longitude, @poi.latitude)
            @poi.save

            @poi2 = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            lat_long = {
              latitude: 20,
              longitude: 20
            }
            @poi2.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long)
            @poi2.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi2.longitude, @poi2.latitude)
            @poi2.save

            @person = DataCycleCore::V4::DummyDataHelper.create_data('minimal_person')

            @stored_filter = DataCycleCore::StoredFilter.create(
              name: 'filtered_event_poi',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [{
                'c' => 'd',
                'm' => 'i',
                'n' => 'Inhaltstypen',
                't' => 'classification_alias_ids',
                'v' => [DataCycleCore::ClassificationAlias.find_by(name: 'Person').id, DataCycleCore::ClassificationAlias.find_by(name: 'POI').id, DataCycleCore::ClassificationAlias.find_by(name: 'Veranstaltung').id]
              }],
              api: true
            )

            @stored_filter_poi = DataCycleCore::StoredFilter.create(
              name: 'filtered_poi',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [{
                'c' => 'd',
                'm' => 'i',
                'n' => 'Inhaltstypen',
                't' => 'classification_alias_ids',
                'v' => [DataCycleCore::ClassificationAlias.find_by(name: 'POI').id]
              }],
              api: true
            )

            @stored_filter_place = DataCycleCore::StoredFilter.create(
              name: 'filtered_place',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [{
                'c' => 'd',
                'm' => 'i',
                'n' => 'Inhaltstypen',
                't' => 'classification_alias_ids',
                'v' => [DataCycleCore::ClassificationAlias.find_by(name: 'Ort').id]
              }],
              api: true
            )

            @stored_filter_event = DataCycleCore::StoredFilter.create(
              name: 'filtered_event',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [{
                'c' => 'd',
                'm' => 'i',
                'n' => 'Inhaltstypen',
                't' => 'classification_alias_ids',
                'v' => [DataCycleCore::ClassificationAlias.find_by(name: 'Veranstaltung').id]
              }],
              api: true
            )

            @stored_filter_event_person = DataCycleCore::StoredFilter.create(
              name: 'filtered_event_person',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [{
                'c' => 'd',
                'm' => 'i',
                'n' => 'Inhaltstypen',
                't' => 'classification_alias_ids',
                'v' => [DataCycleCore::ClassificationAlias.find_by(name: 'Person').id, DataCycleCore::ClassificationAlias.find_by(name: 'Veranstaltung').id]
              }],
              api: true
            )

            @stored_filter_person = DataCycleCore::StoredFilter.create(
              name: 'filtered_person',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [{
                'c' => 'd',
                'm' => 'i',
                'n' => 'Inhaltstypen',
                't' => 'classification_alias_ids',
                'v' => [DataCycleCore::ClassificationAlias.find_by(name: 'Person').id]
              }],
              api: true
            )

            @watch_list_event_poi1 = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList1')
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list_event_poi1.id, hashable_id: @event.id, hashable_type: @event.class.name)
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list_event_poi1.id, hashable_id: @poi.id, hashable_type: @poi.class.name)

            @watch_list_poi2 = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList2')
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list_poi2.id, hashable_id: @poi2.id, hashable_type: @poi2.class.name)

            @watch_list_person_poi_poi2 = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList3')
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list_person_poi_poi2.id, hashable_id: @person.id, hashable_type: @person.class.name)
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list_person_poi_poi2.id, hashable_id: @poi.id, hashable_type: @poi.class.name)
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list_person_poi_poi2.id, hashable_id: @poi2.id, hashable_type: @poi2.class.name)

            @watch_list_event_poi = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList4')
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list_event_poi.id, hashable_id: @event_poi.id, hashable_type: @event_poi.class.name)

            # 4 Images
            # 3 POI's
            # 1 Event
            # 1 Person
            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          test 'api/v4/endpoints make sure contentId,filterId and watch_list id are also available on filter root and linked' do
            params = {}
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(5)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                contentId: {
                  in: [
                    @event.id
                  ]
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert(@event.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              filter: {
                linked: {
                  content_location: {
                    contentId: {
                      in: [
                        @event_poi.id
                      ]
                    }
                  }
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert(@event.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              filter: {
                filterId: {
                  in: [
                    @stored_filter_event.id
                  ]
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert(@event.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              filter: {
                linked: {
                  content_location: {
                    filterId: {
                      in: [
                        @stored_filter_place.id
                      ]
                    }
                  }
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert(@event.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              filter: {
                watchListId: {
                  in: [
                    @watch_list_event_poi1.id
                  ]
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                linked: {
                  content_location: {
                    watchListId: {
                      in: [
                        @watch_list_event_poi.id
                      ]
                    }
                  }
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert_equal([@event.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                endpointId: {
                  in: [
                    @watch_list_event_poi1.id
                  ]
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                linked: {
                  content_location: {
                    endpointId: {
                      in: [
                        @watch_list_event_poi.id
                      ]
                    }
                  }
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert_equal([@event.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints parameter union with contentId' do
            params = {}
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(5)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @event.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert(@event.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        "#{@event.id},#{@poi.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)

            # You must not find linked items
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @poi.image.first.id.to_s
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            assert_api_count_result(0)

            # You must not find items by using AND
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @event.id,
                        @poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            assert_api_count_result(0)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      notIn: [
                        @event.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(4)
            assert_equal([@event_poi.id, @poi.id, @poi2.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      notIn: [
                        "#{@event.id},#{@poi.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@event_poi.id, @poi2.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      notIn: [
                        @event.id,
                        @poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            assert_api_count_result(3)
            assert_equal([@event_poi.id, @poi2.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            # OR filters
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @event.id
                      ]
                    }
                  },
                  {
                    contentId: {
                      in: [
                        @poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            # post api_v4_stored_filter_path(params), as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints parameter union with filterId' do
            params = {}
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)
            assert_api_count_result(5)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      in: [
                        @stored_filter_event.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert(@event.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@poi.id, @poi2.id, @event_poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      in: [
                        "#{@stored_filter_poi.id},#{@stored_filter_event.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(4)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id,
                        @stored_filter_event.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            assert_api_count_result(0)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      in: [
                        @stored_filter_event.id,
                        @stored_filter_event_person.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert_equal([@event.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      notIn: [
                        @stored_filter_place.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      notIn: [
                        "#{@stored_filter_event.id},#{@stored_filter_person.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@poi.id, @poi2.id, @event_poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      notIn: [
                        @stored_filter_event.id,
                        @stored_filter_person.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@poi.id, @poi2.id, @event_poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    filterId: {
                      in: [
                        @stored_filter_event.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(4)
            assert_equal([@poi.id, @poi2.id, @event_poi.id, @event.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints parameter union with watchListId' do
            params = {}
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)
            assert_api_count_result(5)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      in: [
                        @watch_list_event_poi1.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      in: [
                        @watch_list_person_poi_poi2.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@person.id, @poi.id, @poi2.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      in: [
                        "#{@watch_list_event_poi1.id},#{@watch_list_person_poi_poi2.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(4)
            assert_equal([@event.id, @person.id, @poi.id, @poi2.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      in: [
                        @watch_list_event_poi1.id,
                        @watch_list_person_poi_poi2.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert_equal([@poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      notIn: [
                        @watch_list_person_poi_poi2.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event.id, @event_poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      notIn: [
                        "#{@watch_list_event_poi1.id},#{@watch_list_poi2.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      notIn: [
                        @watch_list_event_poi1.id,
                        @watch_list_poi2.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      in: [
                        @watch_list_event_poi1.id
                      ]
                    }
                  },
                  {
                    watchListId: {
                      in: [
                        @watch_list_poi2.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@event.id, @poi.id, @poi2.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints parameter combine id filters' do
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(4)
            assert_equal([@poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    watchListId: {
                      in: [
                        @watch_list_event_poi1.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@event.id, @poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    watchListId: {
                      in: [
                        @watch_list_event_poi1.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(4)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    watchListId: {
                      in: [
                        @watch_list_event_poi1.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(5)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    endpointId: {
                      in: [
                        "#{@watch_list_event_poi1.id},#{@stored_filter_poi.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(4)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id].sort, json_data['@graph'].pluck('@id').sort)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    endpointId: {
                      in: [
                        "#{@watch_list_event_poi1.id},#{@stored_filter_poi.id}"
                      ]
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(5)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)
          end

          test 'api/v4/endpoints parameter combine with more filters' do
            orig_ts = @event.updated_at
            @event.update_column(:updated_at, 10.days.ago)
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  },
                  attribute: {
                    'dct:modified': {
                      in: {
                        max: 5.days.ago.to_fs(:iso8601)
                      }
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(5)
            assert_equal([@event.id, @poi.id, @poi2.id, @event_poi.id, @person.id].sort, json_data['@graph'].pluck('@id').sort)
            @event.update_column(:updated_at, orig_ts)

            orig_ts = @event.updated_at
            @event.update_column(:updated_at, 10.days.ago)
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    },
                    attribute: {
                      'dct:modified': {
                        in: {
                          max: 5.days.ago.to_fs(:iso8601)
                        }
                      }
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert_equal([@person.id].sort, json_data['@graph'].pluck('@id').sort)
            @event.update_column(:updated_at, orig_ts)

            orig_ts = @poi.updated_at
            @poi.update_column(:updated_at, 10.days.ago)
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ],
                attribute: {
                  'dct:modified': {
                    in: {
                      max: 5.days.ago.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(1)
            assert_equal([@poi.id].sort, json_data['@graph'].pluck('@id').sort)
            @poi.update_column(:updated_at, orig_ts)

            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ],
                geo: {
                  in: {
                    box: ['1', '1', '10', '10']
                  }
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event_poi.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)

            # distance: 1 degree ~ 111km
            distance_one_degree = 111 * 1000
            params = {
              filter: {
                union: [
                  {
                    contentId: {
                      in: [
                        @person.id
                      ]
                    }
                  },
                  {
                    filterId: {
                      in: [
                        @stored_filter_poi.id
                      ]
                    }
                  }
                ],
                geo: {
                  in: {
                    perimeter: ['1', '1', (7 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(2)
            assert_equal([@event_poi.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)

            # distance: 1 degree ~ 111km
            distance_one_degree = 111 * 1000
            params = {
              filter: {
                union: [
                  {
                    linked: {
                      content_location: {
                        geo: {
                          in: {
                            perimeter: ['1', '1', (7 * distance_one_degree)]
                          }
                        }
                      }
                    }
                  },
                  {
                    geo: {
                      in: {
                        perimeter: ['1', '1', (7 * distance_one_degree)]
                      }
                    }
                  }
                ]
              }
            }
            post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
            json_data = response.parsed_body
            assert_api_count_result(3)
            assert_equal([@event.id, @event_poi.id, @poi.id].sort, json_data['@graph'].pluck('@id').sort)
          end
        end
      end
    end
  end
end
