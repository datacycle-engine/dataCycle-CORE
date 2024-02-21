# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module Schedules
          def self.add_schedule_from_single_occurrence(data, external_source_id)
            data['event_schedule'] = []
            data['start_date'] = data['startDate']&.in_time_zone
            data['end_date'] = data['endDate']&.in_time_zone
            return data if data['start_date'].blank? || data['end_date'].blank?
            return data if data['start_date'] > data['end_date']

            schedule = {}
            schedule['external_key'] = "Schedule - #{data['external_key']}"
            schedule = DataCycleCore::Generic::Common::DataReferenceTransformations.add_external_schedule_references(schedule, 'id', external_source_id, 'external_key')
            schedule['id'] = schedule['id']&.first

            dtstart = data['start_date']
            dtend = data['end_date']
            duration = dtend - dtstart

            data['event_schedule'] = [{
              id: schedule['id'],
              external_source_id:,
              external_key: schedule['external_key'],
              start_time: {
                time: dtstart.to_s,
                zone: dtstart.time_zone.name
              },
              duration:
            }]
            data
          end
        end
      end
    end
  end
end
