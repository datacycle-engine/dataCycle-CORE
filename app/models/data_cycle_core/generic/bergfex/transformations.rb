# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Bergfex::TransformationFunctions[*args]
        end

        def self.bergfex_to_see(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Bergfex - See - #{s.dig('id')}" })
          .>> t(:reject_keys, ['id', 'region'])
          .>> t(:rename_keys, {
            'name' => 'name_old',
            'area' => 'area_old',
            'depth' => 'depth_old',
            'temperature' => 'temperature_old'
          })
          .>> t(:add_field, 'name', ->(s) { s.dig('name_old', 'text') })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('lat', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('lng', 'text')&.to_f })
          .>> t(:add_field, 'location', ->(s) { RGeo::Geographic.spherical_factory(srid: 4326).point(s['longitude'], s['latitude']) if s['longitude'] && s['latitude'] })
          .>> t(:add_field, 'temperature', ->(s) { s.dig('temperature_old', 'text')&.to_f })
          .>> t(:add_field, 'temp_at', ->(s) { s.dig('temperature_old', 't') })
          .>> t(:add_field, 'quality', ->(s) { s.dig('quality', 'text') })
          .>> t(:nest, 'water_temp', ['temperature', 'temp_at', 'quality'])
          .>> t(:add_field, 'area', ->(s) { s.dig('area_old', 'text')&.to_f })
          .>> t(:add_field, 'depth', ->(s) { s.dig('depth_old', 'text')&.to_f })
          .>> t(:reject_keys, ['name_old', 'lat', 'lng', 'temperature_old', 'area_old', 'depth_old'])
          .>> t(:add_field, 'DateFrom', ->(s) { s.dig('season', 'start', 'text') })
          .>> t(:add_field, 'DateTo', ->(s) { s.dig('season', 'end', 'text') })
          .>> t(:reject_keys, ['season'])
          .>> t(:add_field, 'TimeFrom', ->(s) { s.dig('openinghours', 'from', 'text') || '' })
          .>> t(:add_field, 'TimeTo', ->(s) { s.dig('openinghours', 'to', 'text') || '' })
          .>> t(:nest, 'opening_hours', ['DateFrom', 'DateTo', 'TimeFrom', 'TimeTo'])
          .>> t(:add_field, 'opening_hours_specification', ->(s) { DataCycleCore::Generic::Common::OpeningHours.parse_opening_times(s.dig('opening_hours'), external_source_id, s['external_key']) })
          .>> t(:add_field, 'url', ->(s) { s.dig('link', 'text') })
          .>> t(:reject_keys, ['opening_hours', 'time', 'link'])
          .>> t(:strip_all)
        end

        def self.bergfex_to_ski_resort(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Bergfex - Skigebiet - #{s.dig('id')}" })
          .>> t(:reject_keys, ['id', 'image'])
          .>> t(:rename_keys, {
            'id' => 'external_key',
            'name' => 'name_old',
            'snow' => 'snow_old',
            'addons' => 'addons_old'
          })
          .>> t(:add_field, 'name', ->(s) { s.dig('name_old', 'text') || s.dig('name_old', '#cdata-section') })
          .>> t(:add_field, 'description', ->(s) { s.dig('remarks', '#cdata-section') })
          .>> t(:add_links, 'bergfex_status_icon', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('bergfexStatusIcon', 'id').present? ? ["Bergfex - Status - Icon -#{s&.dig('bergfexStatusIcon', 'id')}"] : [] })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('lat', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('lng', 'text')&.to_f })
          .>> t(:add_field, 'location', ->(s) { RGeo::Geographic.spherical_factory(srid: 4326).point(s['longitude'], s['latitude']) if s['longitude'] && s['latitude'] })
          .>> t(:add_field, 'date_time_updated_at', ->(s) { s.dig('datetime', 'text') })
          .>> t(:add_field, 'date_last_snowfall', ->(s) { s.dig('dateLastSnowfall', 'text') })
          .>> t(:add_field, 'value', ->(s) { s.dig('openLifts', 'text')&.to_i })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('openLifts', 'max')&.to_i })
          .>> t(:nest, 'lifts', ['value', 'max_value'])
          .>> t(:reject_keys, ['value', 'max_value'])
          .>> t(:add_field, 'value', ->(s) { s.dig('openSlopes', 'text')&.to_f })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('openSlopes', 'max')&.to_f })
          .>> t(:nest, 'slopes', ['value', 'max_value'])
          .>> t(:reject_keys, ['value', 'max_value'])
          .>> t(:add_field, 'value', ->(s) { s.dig('openSlopesCount', 'text')&.to_i })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('openSlopesCount', 'max')&.to_i })
          .>> t(:nest, 'count_open_slopes', ['value', 'max_value'])
          .>> t(:reject_keys, ['value', 'max_value'])
          .>> t(:add_field, 'length_nordic_classic', ->(s) { s.dig('lengthNordicClassic', 'text')&.to_f })
          .>> t(:add_field, 'length_nordic_skating', ->(s) { s.dig('lengthNordicSkating', 'text')&.to_f })
          .>> t(:nest, 'operations', ['operation', 'operationRemarks', 'operationStart', 'operationEnd'])
          .>> t(:operations_to_opening_hours, external_source_id, 'opening_hours_specification', 'operations')
          .>> t(:reject_keys, ['operations'])
          .>> t(:add_field, 'same_as', ->(s) { s.dig('linkDetailedReport', 'text') })
          .>> t(:add_field, 'addons', ->(s) { (s.dig('addons_old', 'addon').present? ? (s.dig('addons_old', 'addon').is_a?(Hash) ? [s.dig('addons_old', 'addon')] : s.dig('addons_old', 'addon')) : []) })
          .>> t(:add_links, 'condition_avalanche_warning_level', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('avalancheWarningLevel', 'id').present? ? ["CATEGORY:#{s&.dig('avalancheWarningLevel', 'id')}"] : [] })
          .>> t(:add_links, 'condition_nordic_classic', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionNordicClassic', 'id').present? ? ["CATEGORY:#{s&.dig('conditionNordicClassic', 'id')}"] : [] })
          .>> t(:add_links, 'condition_nordic_skating', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionNordicSkating', 'id').present? ? ["CATEGORY:#{s&.dig('conditionNordicSkating', 'id')}"] : [] })
          .>> t(:add_links, 'condition_run_to_valley', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionRunToValley', 'id').present? ? ["CATEGORY:#{s&.dig('conditionRunToValley', 'id')}"] : [] })
          .>> t(:add_links, 'condition_slopes', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionSlopes', 'id').present? ? ["CATEGORY:#{s&.dig('conditionSlopes', 'id')}"] : [] })
          .>> t(:add_links, 'condition_snow', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionSnow', 'id').present? ? ["CATEGORY:#{s&.dig('conditionSnow', 'id')}"] : [] })
          .>> t(:reject_keys, ['name_old', 'lat', 'lng', 'dateLastSnowfall', 'datetime', 'openLifts', 'openSlopes', 'linkDetailedReport'])
          .>> t(:strip_all)
        end

        def self.bergfex_to_ski_report(external_source_id, locale)
          t(:stringify_keys)
          .>> t(:rename_keys, {
            'elevation' => 'elevation_old',
            'depth' => 'depth_old'
          })
          .>> t(:add_field, 'elevation', ->(s) { s.dig('elevation_old')&.to_f })
          .>> t(:add_field, 'depth_of_snow', ->(s) { s.dig('depth_old', 'text')&.to_f })
          .>> t(:add_field, 'depth_of_fresh_snow', ->(s) { s.dig('depthFresh24', 'text')&.to_f })
          .>> t(:add_field, 'identifier', ->(s) { s.dig('type') })
          .>> t(:get_title_from_locale, 'name', ->(s) { s.dig('type') }, locale)
          .>> t(:add_links, 'condition_weather', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionWeather', 'id').present? ? ["CATEGORY:#{s&.dig('conditionWeather', 'id')}"] : [] })
          .>> t(:strip_all)
        end

        def self.to_ski_resort_new(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Bergfex - Skigebiet - #{s.dig('id')}" })
          .>> t(:rename_keys, {
            'name' => 'name_old',
            'snow' => 'snow_old',
            'addons' => 'addons_old'
          })
          .>> t(:add_field, 'name', ->(s) { s.dig('name_old', 'text') || s.dig('name_old', '#cdata-section') })
          .>> t(:add_field, 'description', ->(s) { s.dig('remarks', '#cdata-section') })
          .>> t(:add_links, 'bergfex_status_icon', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('bergfexStatusIcon', 'id').present? ? ["Bergfex - Status - Icon -#{s&.dig('bergfexStatusIcon', 'id')}"] : [] })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('lat', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('lng', 'text')&.to_f })
          .>> t(:add_field, 'location', ->(s) { RGeo::Geographic.spherical_factory(srid: 4326).point(s['longitude'], s['latitude']) if s['longitude'] && s['latitude'] })
          .>> t(:add_field, 'date_time_updated_at', ->(s) { s.dig('datetime', 'text') })
          .>> t(:map_value, 'telephone', ->(s) { s&.dig('text') })
          .>> t(:nest, 'contact_info', ['telephone'])
          .>> t(:add_field, 'value', ->(s) { s.dig('openLifts', 'text')&.to_i })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('openLifts', 'max')&.to_i })
          .>> t(:nest, 'lifts', ['value', 'max_value'])
          .>> t(:reject_keys, ['value', 'max_value'])
          .>> t(:add_field, 'value', ->(s) { s.dig('openSlopes', 'text')&.to_f })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('openSlopes', 'max')&.to_f })
          .>> t(:nest, 'slopes', ['value', 'max_value'])
          .>> t(:reject_keys, ['value', 'max_value'])
          .>> t(:add_field, 'value', ->(s) { s.dig('openSlopesCount', 'text')&.to_i })
          .>> t(:add_field, 'max_value', ->(s) { s.dig('openSlopesCount', 'max')&.to_i })
          .>> t(:nest, 'count_open_slopes', ['value', 'max_value'])
          .>> t(:reject_keys, ['value', 'max_value'])
          .>> t(:add_field, 'length_nordic_classic', ->(s) { s.dig('lengthNordicClassic', 'text')&.to_f })
          .>> t(:add_field, 'length_nordic_skating', ->(s) { s.dig('lengthNordicSkating', 'text')&.to_f })
          .>> t(:operation_to_status, 'status', 'operation')
          .>> t(:nest, 'operations', ['operation', 'operationRemarks', 'operationStart', 'operationEnd'])
          .>> t(:operations_to_opening_hours, external_source_id, 'opening_hours_specification', 'operations')
          .>> t(:reject_keys, ['operations'])
          .>> t(:add_field, 'same_as', ->(s) { s.dig('linkDetailedReport', 'text') })
          .>> t(:add_field, 'addons', ->(s) { (s.dig('addons_old', 'addon').present? ? (s.dig('addons_old', 'addon').is_a?(Hash) ? [s.dig('addons_old', 'addon')] : s.dig('addons_old', 'addon')) : []) })
          .>> t(:add_links, 'condition_avalanche_warning_level', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('avalancheWarningLevel', 'id').present? ? ["CATEGORY:#{s&.dig('avalancheWarningLevel', 'id')}"] : [] })
          .>> t(:add_links, 'condition_nordic_classic', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionNordicClassic', 'id').present? ? ["CATEGORY:#{s&.dig('conditionNordicClassic', 'id')}"] : [] })
          .>> t(:add_links, 'condition_nordic_skating', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionNordicSkating', 'id').present? ? ["CATEGORY:#{s&.dig('conditionNordicSkating', 'id')}"] : [] })
          .>> t(:add_links, 'condition_run_to_valley', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionRunToValley', 'id').present? ? ["CATEGORY:#{s&.dig('conditionRunToValley', 'id')}"] : [] })
          .>> t(:add_links, 'condition_slopes', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionSlopes', 'id').present? ? ["CATEGORY:#{s&.dig('conditionSlopes', 'id')}"] : [] })
          .>> t(:add_field, 'snow_report', ->(s) { DataCycleCore::Thing.where(external_source_id: external_source_id).where('external_key ILIKE ?', "Bergfex - Schneeebericht - #{s&.dig('id')} - %")&.ids })
          .>> t(:reject_keys, ['name_old', 'lat', 'lng', 'dateLastSnowfall', 'datetime', 'openLifts', 'openSlopes', 'linkDetailedReport'])
          .>> t(:reject_keys, ['id', 'image'])
          .>> t(:strip_all)
        end

        def self.to_snow_report_new(external_source_id, locale)
          t(:stringify_keys)
          .>> t(:rename_keys, {
            'elevation' => 'elevation_old',
            'depth' => 'depth_old'
          })
          .>> t(:add_field, 'date_time_measured', ->(s) { s.dig('datetime', 'text')&.in_time_zone })
          .>> t(:add_field, 'elevation', ->(s) { s.dig('elevation_old')&.to_f })
          .>> t(:add_field, 'depth_of_snow', ->(s) { s.dig('depth_old', 'text')&.to_f })
          .>> t(:add_field, 'depth_of_fresh_snow', ->(s) { s.dig('depthFresh24', 'text')&.to_f })
          .>> t(:add_field, 'last_snowfall', ->(s) { s.dig('dateLastSnowfall', 'text') })
          .>> t(:add_field, 'identifier', ->(s) { s.dig('type') })
          .>> t(:get_title_from_locale, 'alternative_name', ->(s) { s.dig('type') }, locale)
          .>> t(:add_field, 'name', ->(s) { [s.dig('resort', 'text'), s.dig('alternative_name')].join(' - ') })
          .>> t(:parse_condition_snow, 'snow_type', 'odta:snowType')
          .>> t(:parse_condition_snow, 'condition_snow', 'odta:snowCondition')
          .>> t(:add_links, 'condition_weather', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionWeather', 'id').present? ? ["CATEGORY:#{s&.dig('conditionWeather', 'id')}"] : [] })
          .>> t(:add_field, 'external_key', ->(s) { "Bergfex - Schneeebericht - #{s.dig('resort', 'id')} - #{s.dig('id')} (#{s.dig('type')})" })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
