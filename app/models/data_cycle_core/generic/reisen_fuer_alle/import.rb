# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module Import
        def self.import_data(utility_object:, options:)
          feratel_name = utility_object.external_source.credentials['external_source_feratel'] || 'feratel'
          outdoor_active_name = utility_object.external_source.credentials['external_source_outdoor_active'] || 'outdooractive'
          @feratel = DataCycleCore::ExternalSystem.find_by(identifier: feratel_name)
          @outdoor_active = DataCycleCore::ExternalSystem.find_by(identifier: outdoor_active_name)
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

            ['deaf', 'mental', 'partiall_deaf', 'partially_visual', 'visual', 'walking', 'wheelchair'].each do |kind|
              next if raw_data.dig('certificate_data', kind, 'level') == 'none'
              next if raw_data.dig('certificate_data', kind, 'icon_url').blank?
              icon_data = {
                'name' => "#{kind} - #{raw_data.dig('certificate_data', kind, 'level')}",
                'url' => raw_data.dig('certificate_data', kind, 'icon_url'),
                'description' => 'none'
              }
              DataCycleCore::Generic::ReisenFuerAlle::Processing.process_icon(
                utility_object,
                icon_data,
                options.dig(:import, :transformations, :icon)
              )
            end

            if @feratel # TODO: allow for more than one id!!
              feratel_keys = raw_data['third_party_ids']
                .select { |i| i['key'] == 'deskline_id' || i['key'] == 'deskline_id_2' }
                .map { |i| i.dig('value') }
                .map { |i| { external_system_id: @feratel.id, external_key: i, limit: 1 } }
              raw_data['feratel'] = feratel_keys if feratel_keys.present?
            end

            if @outdoor_active
              outdoor_active_key = raw_data['third_party_ids'].detect { |i| i['key'] == 'outdooractive_id' }&.dig('value')
              raw_data['outdoor_active'] = { external_system_id: @outdoor_active.id, external_key: outdoor_active_key, limit: 1 } if outdoor_active_key.present?
            end

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
