# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Zamg
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_weather(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "ZAMG - Station: #{s.dig('01_station', 'statnr')}" })
          .>> t(:add_field, 'elevation', ->(s) { s.dig('01_station', 'hoehe')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('01_station', 'laenge')&.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('01_station', 'breite')&.to_f })
          .>> t(:location)
          .>> t(:add_field, 'email', ->(s) { s.dig('metadata', 'contact', "person name=\"GENERAL CONTACT\"", 'email1') }) # rubocop:disable Style/StringLiterals
          .>> t(:add_field, 'telephone', ->(s) { s.dig('metadata', 'contact', "person name=\"GENERAL CONTACT\"", 'phone') }) # rubocop:disable Style/StringLiterals
          .>> t(:add_field, 'url', ->(s) { s.dig('metadata', 'contact', "person name=\"GENERAL CONTACT\"", 'web') }) # rubocop:disable Style/StringLiterals
          .>> t(:nest, 'contact_info', ['email', 'telephone', 'url'])
          .>> t(:add_field, 'forecasts', ->(s) { parse_forecasts(s, external_source_id) })
          .>> t(:reject_keys, ['metadata', '01_station'])
          .>> t(:strip_all)
        end

        def self.parse_forecasts(hash, external_source_id)
          return_data = []
          hash.dig('02_prognose').each do |datum, forecast|
            forecast_hash = {}
            forecast_hash['forecast_date'] = datum.in_time_zone
            single_forecast = {}
            forecast.each do |time, single|
              temp_key = 'temperature_' + time
              temperature = single.dig('tl')&.to_i
              t_min = single.dig('tlmin')&.to_i
              t_max = single.dig('tlmax')&.to_i
              forecast_icon = single.dig('symb')&.downcase
              symbol_classification = get_symbol_classification(forecast_icon, external_source_id)
              text_d = single.dig('text_d')
              data_hash = {}
              data_hash = data_hash.merge('temperature' => temperature) if temperature.present?
              data_hash = data_hash.merge('forecast_icon' => [symbol_classification&.id].compact)
              data_hash = data_hash.merge('forecast' => get_forecast_description(symbol_classification))
              data_hash = data_hash.merge('minimum_temperature' => t_min) if t_min.present?
              data_hash = data_hash.merge('maximum_temperatur' => t_max) if t_max.present?
              data_hash = data_hash.merge('forecast_text' => text_d) if text_d.present?
              basic_data = {
                'clouds' => single.dig('N')&.to_i,
                'wind_direction_degrees' => single.dig('dd')&.to_i,
                'wind_direction_text' => single.dig('ddh'),
                'wind_velocity' => single.dig('ff')&.to_i,
                'fresh_snow' => single.dig('nschnee')&.to_i,
                'frost_line' => single.dig('nullgrad')&.to_i,
                'precipitation_probability' => single.dig('rrp')&.to_i,
                'precipitation' => single.dig('rrr')&.to_f,
                'snow_line' => single.dig('sgrenze')&.to_i,
                'hours_of_sunshine' => single.dig('sonne')&.to_f,
                'thunderstorm_probability' => single.dig('wgew')&.to_i
              }
              data_hash = data_hash.merge(basic_data)
              single_forecast[temp_key] = [data_hash]
            end
            forecast_hash['temperature_forecasts'] = [single_forecast]
            return_data << forecast_hash
          end
          return_data
        end

        def self.get_forecast_description(symbol)
          return [] if symbol.blank?
          symbol.primary_classification_alias.description
        end

        def self.get_symbol_classification(symbol, external_source_id)
          return if symbol.blank?
          DataCycleCore::Classification.find_by(
            external_source_id: external_source_id,
            external_key: "ZAMG - Symbolcode - #{symbol}"
          )
        end
      end
    end
  end
end
