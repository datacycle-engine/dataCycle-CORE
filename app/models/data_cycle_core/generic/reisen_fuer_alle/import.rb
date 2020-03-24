# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module Import
        def self.import_data(utility_object:, options:)
          feratel_name = utility_object.external_source.credentials['external_source_feratel'] || 'Feratel'
          outdoor_active_name = utility_object.external_source.credentials['external_source_outdoor_active'] || 'OutdoorActive'
          @feratel = DataCycleCore::ExternalSource.find_by(name: feratel_name)
          @outdoor_active = DataCycleCore::ExternalSource.find_by(name: outdoor_active_name)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists' => true } }.merge(source_filter))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            next if raw_data.dig('third_party_ids').blank?

            feratel_key = raw_data['third_party_ids'].detect { |i| i['key'] == 'deskline_id' }&.dig('value')
            raw_data['feratel'] = { external_source_id: @feratel.id, external_key: feratel_key } if feratel_key.present?

            outdoor_active_key = raw_data['third_party_ids'].detect { |i| i['key'] == 'outdooractive_id' }&.dig('value')
            raw_data['outdoor_active'] = { external_source_id: @outdoor_active, external_key: outdoor_active_key } if outdoor_active_key.present?

            DataCycleCore::Generic::ReisenFuerAlle::Processing.process_rating(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :rating)
            )
          end
        end
      end
    end
  end
end
