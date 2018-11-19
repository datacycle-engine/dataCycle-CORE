# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Bergfex::TransformationFunctions[*args]
        end

        def self.bergfex_to_see
          t(:stringify_keys)
          .>> t(:reject_keys, ['region'])
          .>> t(:rename_keys, {
            'id' => 'external_key',
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
          .>> t(:add_field, 'valid_from', ->(s) { s.dig('season', 'start', 'text') })
          .>> t(:add_field, 'valid_through', ->(s) { s.dig('season', 'end', 'text') })
          .>> t(:reject_keys, ['season'])
          .>> t(:add_field, 'opens', ->(s) { s.dig('openinghours', 'from', 'text') || '' })
          .>> t(:add_field, 'closes', ->(s) { s.dig('openinghours', 'to', 'text') || '' })
          .>> t(:nest, 'season', ['valid_from', 'valid_through'])
          .>> t(:nest, 'opening_data', ['season', 'opens', 'closes'])
          .>> t(:add_field, 'opening_hours_specification', ->(s) { [s.dig('opening_data')] })
          .>> t(:add_field, 'url', ->(s) { s.dig('link', 'text') })
          .>> t(:reject_keys, ['season', 'link'])
          .>> t(:strip_all)
        end

        def self.bergfex_to_ski_resort(external_source_id)
          t(:stringify_keys)
          .>> t(:rename_keys, {
            'id' => 'external_key',
            'name' => 'name_old',
            'snow' => 'snow_old'
          })
          .>> t(:add_field, 'name', ->(s) { s.dig('name_old', 'text') })
          .>> t(:add_links, 'bergfex_status_icon', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('bergfexStatusIcon', 'id').present? ? ["Bergfex - Status - Icon -#{s&.dig('bergfexStatusIcon', 'id')}"] : [] })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('lat', 'text')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('lng', 'text')&.to_f })
          .>> t(:add_field, 'location', ->(s) { RGeo::Geographic.spherical_factory(srid: 4326).point(s['longitude'], s['latitude']) if s['longitude'] && s['latitude'] })
          .>> t(:add_field, 'date_time_updated_at', ->(s) { s.dig('datetime', 'text') })
          .>> t(:add_field, 'date_last_snowfall', ->(s) { s.dig('dateLastSnowfall', 'text') })
          .>> t(:add_field, 'open_lifts', ->(s) { s.dig('openLifts', 'text')&.to_i })
          .>> t(:add_field, 'open_slopes', ->(s) { s.dig('openSlopes', 'text')&.to_i })
          .>> t(:add_field, 'max_lifts', ->(s) { s.dig('openLifts', 'max')&.to_i })
          .>> t(:add_field, 'max_slopes', ->(s) { s.dig('openSlopes', 'max')&.to_i })
          .>> t(:nest, 'operations', ['operation', 'operationRemarks', 'operationStart', 'operationEnd'])
          .>> t(:operations_to_opening_hours, 'opening_hours', 'operations')
          .>> t(:reject_keys, ['operations'])
          .>> t(:add_field, 'url', ->(s) { s.dig('linkDetailedReport', 'text') })
          .>> t(:add_links, 'condition_avalanche_warning_level', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('avalancheWarningLevel', 'id').present? ? ["CATEGORY:#{s&.dig('avalancheWarningLevel', 'id')}"] : [] })
          .>> t(:add_links, 'condition_nordic_classic', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionNordicClassic', 'id').present? ? ["CATEGORY:#{s&.dig('conditionNordicClassic', 'id')}"] : [] })
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
          .>> t(:get_title_from_locale, 'name', ->(s) { s.dig('type') }, locale)
          .>> t(:add_links, 'condition_weather', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('conditionWeather', 'id').present? ? ["CATEGORY:#{s&.dig('conditionWeather', 'id')}"] : [] })
          .>> t(:strip_all)
        end
      end
    end
  end
end
