# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gip
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_route_feature(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { s.dig('featureMember', 'GeoName', 'fid') })
          .>> t(:reject_keys, ['name'])
          .>> t(:add_field, 'name', ->(s) { s.dig('featureMember', 'GeoName', 'caption') })
          .>> t(:add_field, 'sections', ->(s) { load_feature_sections(s.dig('featureMember', 'GeoName', 'refs', 'ReferenceItem'), external_source_id) })
          .>> t(:add_field, 'line', ->(s) { load_all_sections(s.dig('sections')) })
          .>> t(:reject_keys, ['boundedBy', 'schemaLocation', 'featureMember']) # 'featureMember'
          .>> t(:strip_all)
        end

        def self.to_route(prefix)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { prefix + s.dig('value') })
          .>> t(:add_field, 'sections', ->(s) { load_sections(s, prefix) })
          .>> t(:add_field, 'line', ->(s) { load_all_sections(s.dig('sections')) })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: prefix + s['value'])&.ids })
          .>> t(:strip_all)
        end

        def self.load_feature_sections(refs, external_source_id)
          return [] if refs.blank?
          external_keys = Array.wrap(refs)
            .map { |i| i.dig('fid') }
            .map { |i| i.split('_').last }
            .map { |i| "Event_#{i}" }
          DataCycleCore::Thing.where(external_key: external_keys, external_source_id: external_source_id)&.ids
        end

        def self.load_all_sections(data)
          return nil if data.blank?
          factory = RGeo::Cartesian.factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: true)
          all_line_strings = DataCycleCore::Thing
            .where(id: data)
            .map(&:line)
            .map(&:to_a) # import all sections as multi_line_string
            .flatten
          factory.multi_line_string(all_line_strings) if all_line_strings.present?
        end

        def self.load_sections(data, prefix)
          DataCycleCore::Classification
            .find_by(external_key: prefix + data['value'])
            &.things
            &.where(template_name: 'Teilstrecke')
            &.ids
        end

        def self.to_section(external_source_id)
          t(:stringify_keys)
          .>> t(:rename_keys, { 'id' => 'external_key', 'caption' => 'name' })
          .>> t(:add_field, 'line', ->(s) { parse_section(s.dig('geometry')) })
          .>> t(:universal_classifications, ->(s) { value_of_attribute(s.dig('properties', 'attributes'), 'att8', 'GEONAME - EUROVELO - ', external_source_id) })
          .>> t(:universal_classifications, ->(s) { value_of_attribute(s.dig('properties', 'attributes'), 'att9', 'GEONAME - ATROUTE - ', external_source_id) })
          .>> t(:reject_keys, ['bbox', 'geometry', 'properties'])
          .>> t(:strip_all)
        end

        def self.value_of_attribute(data, attribute, prefix, external_source_id)
          value = data.detect { |i| i.dig('id') == "StringAttribute_#{attribute}" }&.dig('properties', 'stringvalue')
          value = DataCycleCore::Classification.where(external_key: prefix + value, external_source_id: external_source_id)&.ids if value.present?
          value.presence
        end

        def self.parse_section(geometry)
          return nil if geometry.blank? || geometry.dig('coordinates').blank? || geometry.dig('SRID').blank?
          return if geometry.dig('SRID') != 31_256 # Österreich Ost
          # factory_source = RGeo::Cartesian.factory(srid: 31_256, proj4: '+proj=tmerc +lat_0=0 +lon_0=16.33333333333333 +k=1 +x_0=0 +y_0=-5000000 +ellps=bessel +towgs84=577.326,90.129,463.919,5.137,1.474,5.297,2.4232 +units=m +no_defs ')
          factory_source = RGeo::Geographic.spherical_factory(srid: 31_256, proj4: '+proj=tmerc +lat_0=0 +lon_0=16.33333333333333 +k=1 +x_0=0 +y_0=-5000000 +ellps=bessel +towgs84=577.326,90.129,463.919,5.137,1.474,5.297,2.4232 +units=m +no_defs ')
          # longlat = RGeo::Cartesian.factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: true)
          longlat = RGeo::Geographic.spherical_factory(srid: 4326, proj4: '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs', has_z_coordinate: true)

          coordinates = geometry['coordinates']
          source_coordinates =
            if geometry['type'] == 'LineString'
              factory_source.multi_line_string(
                Array.wrap(
                  factory_source.line_string(
                    coordinates.map { |i| factory_source.point(*i) }
                  )
                )
              )
            elsif geometry['type'] == 'MultiLineString'
              factory_source.multi_line_string(
                coordinates.map do |j|
                  factory_source.line_string(
                    j.map { |i| factory_source.point(*i) }
                  )
                end
              )
            else
              raise EndpointError "unknown geometry type found in Gip importer: #{geometry['type']}"
            end

          RGeo::Feature.cast(source_coordinates, factory: longlat, project: true) # convert to longlat with z=0.0
        end
      end
    end
  end
end
