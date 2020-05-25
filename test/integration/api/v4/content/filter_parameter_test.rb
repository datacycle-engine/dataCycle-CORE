# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      class FilterParameterTest < DataCycleCore::V4::Base
        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @content = DataCycleCore::DummyDataHelper.create_data('poi')
          @content.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@content.longitude, @content.latitude)
          @content.save
          @event = DataCycleCore::DummyDataHelper.create_data('event')
          schedule = DataCycleCore::TestPreparations.generate_schedule(8.days.ago.midday, 8.days.from_now, 1.hour).serialize_schedule_object
          @event.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: schedule.dtstart, end_date: schedule.dtend }, event_schedule: [schedule.schedule_object.to_hash] })
        end

        test 'parameter q for fulltext_search with empty string --> all' do
          params = {
            filter: {
              search: ''
            }
          }
          post api_v4_things_path(params)
          assert_api_count_result(3)
        end

        test 'parameter q for fulltext_search multiple hits' do
          params = {
            filter: {
              search: 'Headline'
            }
          }
          post api_v4_things_path(params)
          assert_api_count_result(2)
        end

        test 'parameter filter[:box] for geo-queries' do
          params = {
            filter: {
              geo: {
                in: {
                  box: ['0', '0', '10', '10']
                }
              }
            }
          }
          post api_v4_things_path(params)
          assert_api_count_result(1)
        end

        test 'parameter filter[:from, :to] for event queries' do
          params = {
            fields: 'dct:modified,startDate,endDate',
            filter: {
              attribute: {
                schedule: {
                  in: {
                    min: '01-01-2000',
                    max: '31-12-2030'
                  }
                }
              }
            }
          }
          post api_v4_things_path(params)
          assert_api_count_result(1)
        end

        test 'parameter filter[:from] for event queries' do
          params = {
            fields: 'dct:modified,startDate,endDate',
            filter: {
              attribute: {
                schedule: {
                  in: {
                    min: '01-01-2000'
                  }
                }
              }
            }
          }
          post api_v4_things_path(params)
          assert_api_count_result(1)
        end

        test 'parameter filter[:to] for event queries' do
          params = {
            fields: 'dct:modified,startDate,endDate',
            filter: {
              attribute: {
                schedule: {
                  in: {
                    max: (@event.end_date - 7.days).to_s(:iso8601)
                  }
                }
              }
            }
          }
          post api_v4_things_path(params)
          assert_api_count_result(1)
        end
      end
    end
  end
end
