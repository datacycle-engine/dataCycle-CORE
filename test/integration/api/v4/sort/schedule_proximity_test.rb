# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class ScheduleProximityTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes

            # reverse creation order to make sure default sorting does not distort the result
            @event_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            @event_d.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                name: 'D',
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
                name: 'C',
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
                name: 'B',
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
                name: 'A',
                event_schedule: [
                  DataCycleCore::TestPreparations.generate_schedule(
                    3.months.ago.beginning_of_week.midday + 3.days,
                    1.month.from_now,
                    2.hours,
                    frequency: 'weekly'
                  ).serialize_schedule_object.schedule_object.to_hash
                ]
              })

            @poi = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            @poi.set_data_hash(partial_update: true, prevent_history: true, data_hash:
              {
                name: 'POI',
                opening_hours_specification: [
                  DataCycleCore::TestPreparations.generate_schedule(
                    3.months.ago.beginning_of_week.midday + 4.days,
                    1.month.from_now,
                    2.hours,
                    frequency: 'weekly'
                  ).serialize_schedule_object.schedule_object.to_hash
                ]
              })

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
            @event_count = DataCycleCore::Thing.where(template_name: 'Event').count
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things with default sorting' do
            # default = proximity.inTime for schedule filter
            params = {
              fields: 'name',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(@event_count)

            json_data = response.parsed_body
            assert_equal(['D', 'C', 'B', 'A'], json_data['@graph'].pluck('name'))

            # default = proximity.inTime
            params = {
              fields: 'name',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
                    }
                  }
                }
              },
              sort: 'proximity.inTime'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@event_count)

            json_data = response.parsed_body
            assert_equal(['A', 'B', 'C', 'D'], json_data['@graph'].pluck('name'))
          end

          test 'api/v4/things with sort parameter: proximity.occurrence' do
            # proximity.occurrence
            params = {
              fields: 'name',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
                    }
                  }
                }
              },
              sort: 'proximity.occurrence'
            }
            post api_v4_things_path(params)
            assert_api_count_result(@event_count)

            json_data = response.parsed_body
            assert_equal(['D', 'C', 'B', 'A'], json_data['@graph'].pluck('name'))
          end

          test 'api/v4/things with sort default' do
            params = {
              fields: 'name',
              filter: {
                schedule: {
                  in: {
                    min: Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601),
                    max: Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
                  }
                }
              }
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_api_count_result(@thing_count)
            assert_equal(['D', 'C', 'B', 'A', 'POI'], json_data['@graph'].pluck('name'))

            params = {
              fields: 'name',
              filter: {
                schedule: {
                  in: {
                    min: Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601),
                    max: Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
                  }
                }
              },
              sort: 'proximity.occurrence'
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_api_count_result(@thing_count)
            assert_equal(['D', 'C', 'B', 'A', 'POI'], json_data['@graph'].pluck('name'))
          end

          test 'api/v4/things with sort considering relation' do
            from = Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601)
            to = Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
            params = {
              filter: {
                attribute: {
                  eventSchedule: {
                    in: {
                      min: from,
                      max: to
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_api_count_result(@event_count)
            assert_equal(['D', 'C', 'B', 'A'], json_data['@graph'].pluck('name'))

            params = {
              filter: {
                schedule: {
                  in: {
                    min: from,
                    max: to
                  }
                }
              },
              sort: "proximity.occurrence(#{from},#{to},eventSchedule)"
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_api_count_result(@thing_count)
            assert_equal(['D', 'C', 'B', 'A', 'POI'], json_data['@graph'].pluck('name'))

            params = {
              filter: {
                schedule: {
                  in: {
                    min: from,
                    max: to
                  }
                }
              },
              sort: "proximity.occurrence(#{from},#{to},openingHoursSpecification)"
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_api_count_result(@thing_count)
            assert_equal(['POI', 'A', 'B', 'C', 'D'], json_data['@graph'].pluck('name'))
          end

          test 'api/v4/things with sort and filter with relation' do
            from = Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601)
            to = Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
            params = {
              union: {
                attribute: {
                  eventSchedule: {
                    in: {
                      min: from,
                      max: to
                    }
                  },
                  openingHoursSpecification: {
                    in: {
                      min: from,
                      max: to
                    }
                  }
                }
              },
              sort: "proximity.occurrence(#{from},#{to},openingHoursSpecification)"
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_api_count_result(@thing_count)
            assert_equal(['POI', 'A', 'B', 'C', 'D'], json_data['@graph'].pluck('name'))
          end

          test 'api/v4/things with sort and filter with sort(sortAttr)' do
            from = Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601)
            to = Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
            params = {
              sort: "proximity.occurrence(#{from},#{to},openingHoursSpecification)"
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_equal(['POI', 'A', 'B', 'C', 'D'], json_data['@graph'].pluck('name'))
          end

          test 'api/v4/things with sort and filter sort(start,end)' do
            from = Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601)
            to = Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
            params = {
              sort: "proximity.occurrence(start:#{from},end:#{to})"
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_equal(['D', 'C', 'B', 'A', 'POI'], json_data['@graph'].pluck('name'))
          end

          test 'api/v4/things with sort union filter' do
            params = {
              union: {
                attribute: {
                  eventSchedule: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
                    }
                  },
                  openingHoursSpecification: {
                    in: {
                      min: Time.zone.now.beginning_of_week.beginning_of_day.to_fs(:iso8601),
                      max: Time.zone.now.end_of_week.beginning_of_day.to_fs(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            assert_api_count_result(@thing_count)
            assert_equal(['A', 'B', 'C', 'D', 'POI'], json_data['@graph'].pluck('name'))
          end
        end
      end
    end
  end
end
