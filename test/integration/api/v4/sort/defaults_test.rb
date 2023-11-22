# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class DefaultsTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes

            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_d = {
              'name': 'poi_d',
              'latitude': 1,
              'longitude': 1
            }
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_d)
            @poi_d.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_d.longitude, @poi_d.latitude)
            @poi_d.save

            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_c = {
              'name': 'poi_c',
              'latitude': 10,
              'longitude': 1
            }
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_c)
            @poi_c.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_c.longitude, @poi_c.latitude)
            @poi_c.save

            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_b = {
              'name': 'poi_b',
              'latitude': 5,
              'longitude': 5
            }
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_b)
            @poi_b.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_b.longitude, @poi_b.latitude)
            @poi_b.save

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            lat_long_a = {
              'name': 'poi_a',
              'latitude': 1,
              'longitude': 10
            }
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long_a)
            @poi_a.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@poi_a.longitude, @poi_a.latitude)
            @poi_a.save

            # reverse creation order to make sure default sorting does not distort the result
            @event_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            @event_d.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                name: 'dddddd',
                event_schedule: [
                  DataCycleCore::TestPreparations.generate_schedule(
                    0.months.ago.beginning_of_week.midday + 0.days,
                    4.months.from_now,
                    1.hour,
                    frequency: 'weekly'
                  ).serialize_schedule_object.schedule_object.to_hash
                ]
              })

            @event_c = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            @event_c.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                name: 'cccccc',
                event_schedule: [
                  DataCycleCore::TestPreparations.generate_schedule(
                    1.month.ago.beginning_of_week.midday + 1.day,
                    3.months.from_now,
                    0.hours,
                    frequency: 'weekly'
                  ).serialize_schedule_object.schedule_object.to_hash
                ]
              })

            @event_b = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            @event_b.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                name: 'aaabbb',
                event_schedule: [
                  DataCycleCore::TestPreparations.generate_schedule(
                    2.months.ago.beginning_of_week.midday + 2.days,
                    2.months.from_now,
                    1.hour,
                    frequency: 'weekly'
                  ).serialize_schedule_object.schedule_object.to_hash
                ]
              })

            @event_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            @event_a.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                name: 'aaaaaa',
                event_schedule: [
                  DataCycleCore::TestPreparations.generate_schedule(
                    3.months.ago.beginning_of_week.midday + 3.days,
                    1.month.from_now,
                    2.hours,
                    frequency: 'weekly'
                  ).serialize_schedule_object.schedule_object.to_hash
                ]
              })

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things with default sorting' do
            # default = thing.boost, thing.updated_at, thing.id
            params = {
              fields: 'name'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            json_data = response.parsed_body
            assert_equal(['aaaaaa', 'aaabbb', 'cccccc', 'dddddd', 'poi_a', 'poi_b', 'poi_c', 'poi_d'], json_data.dig('@graph').pluck('name'))
          end

          test 'api/v4/things with implicit sorting' do
            # distance: 1 degree ~ 111km
            distance_one_degree = 111 * 1000
            # default for schedules = proximity.occurrence
            params = {
              fields: 'name',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_s(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            json_data = response.parsed_body

            assert_equal(['dddddd', 'cccccc', 'aaabbb', 'aaaaaa'], json_data.dig('@graph').pluck('name'))

            # default for search = similarity
            params = {
              fields: 'name',
              filter: {
                search: 'aaa'
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            assert_equal(['aaaaaa', 'aaabbb'], json_data.dig('@graph').pluck('name'))

            # default sorting: proximity.geographic ASC
            params = {
              fields: 'name',
              filter: {
                geo: {
                  in: {
                    perimeter: ['1', '1', (10 * distance_one_degree)]
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            json_data = response.parsed_body
            assert_equal(['poi_d', 'poi_b', 'poi_a', 'poi_c'], json_data.dig('@graph').pluck('name'))
          end

          test 'api/v4/things with explicit sorting' do
            # distance: 1 degree ~ 111km
            distance_one_degree = 111 * 1000

            # default for schedules = proximity.inTime
            params = {
              fields: 'name',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_s(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_s(:iso8601)
                    }
                  }
                }
              },
              sort: 'proximity.inTime'
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            json_data = response.parsed_body
            assert_equal(['aaaaaa', 'aaabbb', 'cccccc', 'dddddd'], json_data.dig('@graph').pluck('name'))

            # proximity.occurrence
            params = {
              fields: 'name',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_s(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_s(:iso8601)
                    }
                  }
                }
              },
              sort: 'proximity.occurrence'
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            json_data = response.parsed_body
            assert_equal(['dddddd', 'cccccc', 'aaabbb', 'aaaaaa'], json_data.dig('@graph').pluck('name'))

            # similarity
            params = {
              fields: 'name',
              filter: {
                search: 'aaa'
              },
              sort: '-similarity'
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            assert_equal(['aaaaaa', 'aaabbb'], json_data.dig('@graph').pluck('name'))

            # proximity.geographic ASC
            params = {
              fields: 'name',
              filter: {
                geo: {
                  in: {
                    perimeter: ['1', '1', (10 * distance_one_degree)]
                  }
                }
              },
              sort: 'proximity.geographic'
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            json_data = response.parsed_body
            assert_equal(['poi_d', 'poi_b', 'poi_a', 'poi_c'], json_data.dig('@graph').pluck('name'))
          end

          test 'api/v4/things with explicit over implicit sorting' do
            # default sorting priority schedule -> location -> search
            params = {
              fields: 'name',
              filter: {
                search: 'aaa',
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_s(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            assert_equal(['aaaaaa', 'aaabbb'], json_data.dig('@graph').pluck('name'))

            # overrule sorting priority schedule -> location -> search: search -> schedule
            params = {
              fields: 'name',
              filter: {
                search: 'aaa',
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_s(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_s(:iso8601)
                    }
                  }
                }
              },
              sort: 'similarity'
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = response.parsed_body
            assert_equal(['aaabbb', 'aaaaaa'], json_data.dig('@graph').pluck('name'))
          end
        end
      end
    end
  end
end
