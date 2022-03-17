# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Timm4
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.add_info(data, fields, external_source_id)
          additional_information = fields.map { |type|
            next if data[type].blank?
            external_key = "TIMM4 - AdditionalInformation - #{data.dig('id')} - #{type}"
            {
              'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
              'external_key' => external_key,
              'name' => I18n.t("import.timm4.#{type}", default: [type]),
              'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)),
              'description' => data[type]
            }.compact
          }.compact
          data['additional_information'] = additional_information
          data
        end

        def self.add_contact_name(data)
          return data if data.dig('address').blank?
          address = data.dig('address')
          org = nil
          org = address['organization'] if address['organization']
          contact_name = [address['formOfAddress'], address['firstname'], address['lastname']].compact.join(' ').presence
          data['contact_name'] = [org, contact_name].compact.join(' - ')
          data
        end

        def self.add_images(data, external_source_id)
          images = [data.dig('img'), data.dig('images')]
            .flatten
            .compact
            .map { |i| DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: i)&.id }
            .compact
          data['image'] = images
          data
        end

        def self.add_opening_hours_specification(data, external_source_id)
          return data if data.dig('openingTimes', 'times').blank?
          data['opening_hours_specification'] = []
          data.dig('openingTimes', 'times').each_with_index do |time, index|
            holidays = true if time['weekdays'].include?(8)
            opening_hours_days = time['weekdays'].select { |i| i < 8 }.map { |i| i == 7 ? 0 : i }
            processed = DataCycleCore::Generic::Common::OpeningHours.parse_opening_times({
              'TimeFrom' => time['startTime'],
              'DateFrom' => Time.zone.now.beginning_of_year.to_date,
              'TimeTo' => time['endTime'],
              'DateTo' => (Time.zone.now.end_of_year + 5.years).to_date,
              'Holiday' => holidays,
              'WeekDays' => opening_hours_days
            }, external_source_id, "#{data['id']} - #{index}")
            data['opening_hours_specification'].push(processed)
          end

          data['opening_hours_specification'] = data['opening_hours_specification']&.flatten
          data
        end

        def self.add_opening_hours_description(data)
          return data if data.dig('openingTimes', 'additionalInformation').blank?
          data['opening_hours_description'] = [{ 'description' => data.dig('openingTimes', 'additionalInformation') }]
          data
        end
      end
    end
  end
end
