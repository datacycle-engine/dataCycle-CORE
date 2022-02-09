# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::FeratelWebcam::TransformationFunctions[*args]
        end

        def self.to_slope(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Piste - #{s.dig('ski_region_id')} - #{s.dig('c')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
          .>> t(:add_links, 'snow_resort', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where(external_key: "Feratel Webcams - Schigebiet - #{s.dig('ski_region_id')}")&.pluck(:external_key) })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('st')}", external_source_id: external_source_id)&.ids })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('typ')}", external_source_id: external_source_id)&.ids })
          .>> t(:strip_all)
        end

        def self.to_lift(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Lift - #{s.dig('ski_region_id')} - #{s.dig('c')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
          .>> t(:add_links, 'snow_resort', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap("Feratel Webcams - Schigebiet - #{s.dig('ski_region_id')}") })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('st')}", external_source_id: external_source_id)&.ids })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('typ')}", external_source_id: external_source_id)&.ids })
          .>> t(:strip_all)
        end

        def self.to_infrastructure(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Zusatzangebot - #{s.dig('ski_region_id')} - #{s.dig('c')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('st')}", external_source_id: external_source_id)&.ids })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('typ')}", external_source_id: external_source_id)&.ids })
          .>> t(:strip_all)
        end

        def self.to_ski_region(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Schigebiet - #{s.dig('rid')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
          .>> t(:add_links, 'amenity_feature', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where('external_key ILIKE ? AND external_source_id = ?', "Feratel Webcams - Zusatzangebot - #{s.dig('rid').downcase} - %", external_source_id)&.pluck(:external_key) })
          .>> t(:strip_all)
        end
        # .>> t(:add_links, 'lift_details', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where('external_key ILIKE ? AND external_source_id = ?', "Feratel Webcams - Lift - #{s.dig('rid').downcase} - %", external_source_id)&.pluck(:external_key) })
        # .>> t(:add_links, 'slope_details', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where('external_key ILIKE ? AND external_source_id = ?', "Feratel Webcams - Piste - #{s.dig('rid').downcase} - %", external_source_id)&.pluck(:external_key) })

        def self.to_image
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Image - #{s.dig('type')} - #{s.dig('rid')}" })
          .>> t(:add_field, 'name', ->(s) { "Bild Webcam #{s.dig('type') == 'is' ? 'Highlight' : 'Aktuell'}" })
          .>> t(:hashify_data, 'isi')
          .>> t(:hashify_data, 'hi')
          .>> t(:add_field, 'content_url', ->(s) { s.dig("#{s.dig('type')}i", '36', s.dig('url_key')) })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig("#{s.dig('type')}i", '44', s.dig('url_key')) })
        end

        def self.to_place(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Standort - #{s.dig('rid')}" })
          .>> t(:hashify_data, 'pci')
          .>> t(:add_field, 'elevation', ->(s) { s.dig('pci', '5')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('pci', '8')&.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('pci', '7')&.to_f })
          .>> t(:location)
          .>> t(:add_field, 'url', ->(s) { s.dig('pci', '20') })
          .>> t(:add_field, 'email', ->(s) { s.dig('pci', '21') })
          .>> t(:add_field, 'telephone', ->(s) { s.dig('pci', '23') })
          .>> t(:nest, 'contact_info', ['telephone', 'url', 'email'])
          .>> t(:add_field, 'name', ->(s) { s.dig('pci', '1') || s.dig('pci', '2') || s.dig('pci', '4') })
          .>> t(:add_field, 'url', ->(s) { s.dig('pci', '26', 'v') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { ["Feratel Webcams - Image - is - #{s.dig('rid')}", "Feratel Webcams - Image - h - #{s.dig('rid')}"] })
        end

        def self.to_weather_station(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Wetterstation - #{s.dig('rid')}" })
          .>> t(:hashify_data, 'pci')
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('pci', '3')&.in_time_zone })
          .>> t(:add_field, 'name', ->(s) { s.dig('pci', '1') || s.dig('pci', '2') || s.dig('pci', '4') })
          .>> t(:add_field, 'url', ->(s) { s.dig('pci', '26', 'v') })
          .>> t(:add_links, 'forecasts', DataCycleCore::Thing, external_source_id, ->(s) { generate_forecast_keys(s) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { ["Feratel Webcams - Image - is - #{s.dig('rid')}", "Feratel Webcams - Image - h - #{s.dig('rid')}"] })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { ["Feratel Webcams - Standort - #{s.dig('rid')}"] })
        end

        def self.to_weather_forecast(external_source_id)
          t(:stringify_keys)
          .>> t(:hashify_data, 'pci')
          .>> t(:hashify_data, 'wid')
          .>> t(:rename_keys, { 'ss' => 'sunset', 'sr' => 'sunrise', 'd' => 'forecast_date' })
          .>> t(:add_field, 'name', ->(s) { "#{s.dig('pci', '1') || s.dig('pci', '2') || s.dig('pci', '4')} - #{s.dig('forecast_date').split('T').first} (#{s.dig('elevation')} m)" })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('name') })
          .>> t(:map_value, 'forecast_date', ->(v) { v&.to_date })
          .>> t(:map_value, 'sunset', ->(v) { v&.in_time_zone })
          .>> t(:map_value, 'sunrise', ->(v) { v&.in_time_zone })
          .>> t(:map_value, 'elevation', ->(v) { v&.to_f })
          .>> t(:universal_classifications, ->(s) { day_index(s.dig('wid', '0')).present? ? Array.wrap(DataCycleCore::Classification.find_by(external_source_id: external_source_id, external_key: "Feratel Webcams - Wochentag - #{day_index(s.dig('wid', '0'))}")&.id) : [] })
          .>> t(:add_field, 'minimum_temperature', ->(s) { s.dig('wid', '3')&.to_i })
          .>> t(:add_field, 'maximum_temperature', ->(s) { s.dig('wid', '4')&.to_i })
          .>> t(:universal_classifications, ->(s) { Array.wrap(DataCycleCore::Classification.find_by(external_source_id: external_source_id, external_key: "Feratel Webcams - #{s.dig('weather_provider')} - #{s.dig('wid', '5')}")&.id) })
          .>> t(:add_field, 'wind_direction_degrees', ->(s) { s.dig('wid', '9')&.to_i })
          .>> t(:add_field, 'wind_direction_text', ->(s) { I18n.locale == :de ? s.dig('wid', '10') : s.dig('wid', '11') })
          .>> t(:add_field, 'wind_velocity', ->(s) { s.dig('wid', '12')&.to_i })
          .>> t(:add_field, 'wind_velocity_knots', ->(s) { s.dig('wid', '13')&.to_i })
          .>> t(:add_field, 'forecast_details', ->(s) { parse_forecast_details(s.dig('wid', '8'), s.dig('weather_provider'), external_source_id, "#{s.dig('external_key')} - #{s.dig('forecast_date')}") })
          .>> t(:add_field, 'debug', ->(s) { debug(s) })
        end

        def self.to_webcam(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Webcam - #{s.dig('rid')}" })
          .>> t(:hashify_data, 'pci')
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { ["Feratel Webcams - Image - is - #{s.dig('rid')}", "Feratel Webcams - Image - h - #{s.dig('rid')}"] })
          .>> t(:add_links, 'video', DataCycleCore::Thing, external_source_id, ->(s) { ["Feratel Webcams - Webcam - Small - #{s.dig('rid')}", "Feratel Webcams - Webcam - Large - #{s.dig('rid')}"] })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { ["Feratel Webcams - Standort - #{s.dig('rid')}"] })
          .>> t(:add_field, 'name', ->(s) { 'Webcam: ' + (s.dig('pci', '1') || s.dig('pci', '2') || s.dig('pci', '4')) })
          .>> t(:add_field, 'content_url', ->(s) { "#{s.dig('cam_host')}&pg=#{s.dig('pg')}&cam=#{s.dig('rid')}" })
          .>> t(:add_field, 'url', ->(s) { s.dig('pci', '26', 'v') })
          .>> t(:add_field, 'debug', ->(s) { debug(s) })
        end

        def self.to_video
          t(:stringify_keys)
          .>> t(:unwrap, 'video_data')
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Webcam - #{s.dig('type')} - #{s.dig('rid')}" })
          .>> t(:add_field, 'name', ->(s) { "Webcam Video #{s.dig('type')}" })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('url') })
        end

        def self.debug(data)
          # byebug
        end

        def self.parse_forecast_details(s, provider, external_source_id, parent_external_key)
          return [] if s.blank?
          ['00', '03', '06', '09', '12', '15', '18', '21'].map { |time|
            next if s["t#{time}"].blank?
            universal_classifications = DataCycleCore::Classification.where(external_source_id: external_source_id, external_key: "Feratel Webcams - #{provider} - #{s["s#{time}"]}")&.ids
            universal_classifications += DataCycleCore::Classification.where(external_source_id: external_source_id, external_key: "Feratel Webcams - Tageszeit - #{time}")&.ids
            external_key = "#{parent_external_key} - #{time}"
            id = DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id
            data = {}
            data = { 'id' => id } if id.present?
            data.merge({
              'minimum_temperature' => s.dig("t#{time}m")&.to_i,
              'maximum_temperature' => s.dig("t#{time}")&.to_i,
              'universal_classifications' => universal_classifications,
              'wind_direction_degrees' => s.dig("w#{time}r")&.to_i,
              'wind_direction_text' => I18n.locale == :de ? s.dig("w#{time}rk") : s.dig("w#{time}rt"),
              'wind_velocity' => s.dig("w#{time}g")&.to_i,
              'wind_velocity_knots' => s.dig("w#{time}gk")&.to_i,
              'external_key' => external_key
            })
          }.compact
        end

        def self.generate_forecast_keys(s)
          forecast_data = Array.wrap(s.dig('w')).detect { |i| i['t'] == '10' }
          return [] if forecast_data.blank?
          elevation = forecast_data&.dig('h')
          dates = forecast_data.dig('wi').map { |i| i['d']&.to_date }
          return [] if dates.blank?
          dates.map { |i| "#{s.dig('name')} - #{i} (#{elevation} m)" }
        end

        def self.day_index(day_name)
          index = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'].index(day_name)
          index || ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].index(day_name)
        end
      end
    end
  end
end
