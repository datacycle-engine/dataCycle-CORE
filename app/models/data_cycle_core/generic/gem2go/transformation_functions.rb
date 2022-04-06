# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gem2go
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.add_info(data, fields, external_source_id)
          additional_information = fields.map { |type|
            next if data[type].blank?
            external_key = "GEM2GO - AdditionalInformation - #{data.dig('external_key')} - #{type}"
            {
              'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
              'external_key' => external_key,
              'name' => I18n.t("import.gem2go.#{type}", default: [type]),
              'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)),
              'description' => data[type]
            }.compact
          }.compact
          data['additional_information'] = additional_information
          data
        end

        def self.add_schedule(data, external_source_id, external_key)
          return data if data.dig('timeintervals', 'datetime').blank?
          data['event_schedule'] = []
          Array.wrap(data.dig('timeintervals', 'datetime')).each do |date|
            dtstart = date.dig('start', 'text')&.in_time_zone
            dtend = date.dig('end', 'text')&.in_time_zone
            next if dtstart.blank? || dtend.blank?
            next if dtend < dtstart
            duration = dtend - dtstart

            data['event_schedule'] << {
              start_time: { time: dtstart, zone: dtstart.time_zone.name },
              duration: duration
            }
          end
          data['event_schedule'].map! do |item|
            schedule_key = Digest::SHA1.hexdigest "#{external_key.call(data)}-#{item.to_json}"
            item.merge({
              id: DataCycleCore::Schedule.find_by(external_source_id: external_source_id, external_key: schedule_key)&.id,
              external_source_id: external_source_id,
              external_key: schedule_key
            })
          end
          data
        end
      end
    end
  end
end
