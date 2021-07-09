# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class ScheduleTest < DataCycleCore::V4::Base
          # 8.days.ago - 5.days.ago
          # 5.days.ago - 5.days
          # today - tomorrow
          # 5.days - 10.days
          before(:all) do
            DataCycleCore::Thing.where(template: false).delete_all

            @event_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            schedule_a = DataCycleCore::TestPreparations.generate_schedule(8.days.ago.midday, 5.days.ago, 1.hour).serialize_schedule_object
            @event_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_a.schedule_object.to_hash] })

            @event_b = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            schedule_b = DataCycleCore::TestPreparations.generate_schedule(5.days.ago.midday, 5.days.from_now, 1.hour).serialize_schedule_object
            @event_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_b.schedule_object.to_hash] })

            @event_c = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            schedule_c = DataCycleCore::TestPreparations.generate_schedule(Time.zone.now.beginning_of_day, 1.day.from_now, 1.hour).serialize_schedule_object
            @event_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_c.schedule_object.to_hash] })

            @event_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
            schedule_d = DataCycleCore::TestPreparations.generate_schedule(5.days.from_now.midday, 10.days.from_now, 1.hour).serialize_schedule_object
            @event_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_d.schedule_object.to_hash] })

            @food_establishment_e = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
            schedule_e = DataCycleCore::TestPreparations.generate_schedule(Time.zone.now.beginning_of_day, 1.day.from_now, 1.hour).serialize_schedule_object
            @food_establishment_e.set_data_hash(partial_update: true, prevent_history: true, data_hash: { opening_hours_specification: [schedule_e.schedule_object.to_hash] })

            @food_establishment_f = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
            schedule_f = DataCycleCore::TestPreparations.generate_schedule(Time.zone.now.beginning_of_day, 1.day.from_now, 1.hour).serialize_schedule_object
            schedule_g = DataCycleCore::TestPreparations.generate_schedule(Time.zone.now.beginning_of_day, 1.day.from_now, 1.hour).serialize_schedule_object
            @food_establishment_f.set_data_hash(partial_update: true, prevent_history: true, data_hash: { opening_hours_specification: [schedule_f.schedule_object.to_hash], dining_hours_specification: [schedule_g.schedule_object.to_hash] })

            @thing_count = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded').count
          end

          test 'api/v4/things parameter filter[attribute][schedule]' do
            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            # find all events
            params = {
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: (Time.zone.now - 7.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(4)

            params = {
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: (Time.zone.now + 2.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            params = {
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: (Time.zone.now + 2.days).to_s(:iso8601),
                      max: (Time.zone.now + 3.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            params = {
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      max: (Time.zone.now + 3.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(3)

            params = {
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: Time.zone.now.beginning_of_day.to_s(:iso8601),
                      max: Time.zone.now.end_of_day.to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            params = {
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: (Time.zone.now + 9.days).to_s(:iso8601),
                      max: (Time.zone.now + 20.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            json_data = JSON.parse(response.body)
            assert_equal(@event_d.id, json_data.dig('@graph').first.dig('@id'))

            params = {
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  schedule: {
                    in: {
                      min: (Time.zone.now - 20.days).to_s(:iso8601),
                      max: (Time.zone.now - 7.days).to_s(:iso8601)
                    }
                  }
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(1)

            json_data = JSON.parse(response.body)
            assert_equal(@event_a.id, json_data.dig('@graph').first.dig('@id'))
          end

          test 'api/v4/things parameter filter[schedule]' do
            post api_v4_things_path({
              fields: 'dct:modified,startDate,endDate',
              filter: {
                schedule: {
                  in: {
                    min: (Time.zone.now - 7.days).to_s(:iso8601)
                  }
                }
              }
            })

            assert_api_count_result(6)
          end

          test 'api/v4/things parameter filter[attribute][openingHoursSpecification]' do
            post api_v4_things_path({
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  openingHoursSpecification: {
                    in: {
                      min: (Time.zone.now - 7.days).to_s(:iso8601)
                    }
                  }
                }
              }
            })

            assert_api_count_result(2)
          end

          test 'api/v4/things parameter filter[attribute][dc:diningHoursSpecification]' do
            post api_v4_things_path({
              fields: 'dct:modified,startDate,endDate',
              filter: {
                attribute: {
                  'dc:diningHoursSpecification': {
                    in: {
                      min: (Time.zone.now - 7.days).to_s(:iso8601)
                    }
                  }
                }
              }
            })

            assert_api_count_result(1)
          end
        end
      end
    end
  end
end
