# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gip
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_route_feature(_external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { s.dig('featureMember', 'GeoName', 'fid') })
          .>> t(:reject_keys, ['name'])
          .>> t(:add_field, 'name', ->(s) { s.dig('featureMember', 'GeoName', 'featureName', 'text') })
          .>> t(:add_field, 'description', ->(s) { s.dig('featureMember', 'GeoName', 'schreib6', 'text') })
          .>> t(:add_field, 'route_number', ->(s) { s.dig('featureMember', 'GeoName', 'externalId', 'text') })
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

        def self.load_all_sections(data)
          return nil if data.blank?
          longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
          factory = RGeo::Cartesian.factory(srid: 4326, proj4: longlat_projection, has_z_coordinate: true)
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
            &.where(template_name: 'Route')
            &.ids
        end

        def self.to_section(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { parse_external_id(s) })
          .>> t(:add_field, 'line', ->(s) { parse_section(s.dig('geometry')) })
          .>> t(:add_links, 'bikeroute', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att1' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "Gip - BIKEROUTE - #{item}" }.presence || ['Gip - BIKEROUTE - 1'] })
          .>> t(:add_links, 'owner', DataCycleCore::Classification, external_source_id, ->(s) { parse_owner(s) })
          .>> t(:add_links, 'sustainer', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att2' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "Gip - SUSTAINER - #{item}" }.presence || [] })
          .>> t(:add_links, 'bikecomfort', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att4' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "Gip - BIKECOMFORT - #{item}" }.presence || [] })
          .>> t(:add_links, 'bikeroutestate', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att5' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "Gip - BIKEROUTESTATE - #{item}" }.presence || ['Gip - BIKEROUTESTATE - 0'] })
          .>> t(:add_links, 'signage', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att6' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "Gip - SIGNAGE - #{item}" }.presence || ['Gip - SIGNAGE - -1'] })
          .>> t(:add_links, 'minortyperef', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att7' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "Gip - MINORTYPEREF - #{item}" }.presence || ['Gip - MINORTYPEREF - 110'] })
          .>> t(:add_links, 'eurovelo', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att8' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "GEONAME - EUROVELO - #{item}" }.presence || [] })
          .>> t(:add_links, 'atroute', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att9' }&.dig('properties', 'stringvalue'))&.flatten&.map { |item| "GEONAME - ATROUTE - #{item}" }.presence || [] })
          .>> t(:add_links, 'referencetype', DataCycleCore::Classification, external_source_id, ->(s) { s.dig('properties', 'type') ? Array.wrap("Gip - REFERENCETYPE - #{s.dig('properties', 'type')}") : [] })
          .>> t(:add_links, 'orgcode', DataCycleCore::Classification, external_source_id, ->(s) { s.dig('properties', 'externalorgcode') ? Array.wrap("Gip - ORGCODE - #{s.dig('properties', 'externalorgcode')}") : [] })
          .>> t(:add_field, 'name', ->(s) { "#{s['caption']} - #{DataCycleCore::Classification.find_by(id: s['minortyperef']).name}" })
          .>> t(:add_field, 'routes', ->(s) { load_feature_routes(s.dig('properties', 'geoNameId1'), external_source_id) })
          .>> t(:reject_keys, ['id', 'caption', 'bbox', 'geometry', 'properties'])
          .>> t(:strip_all)
        end

        # def self.value_of_attribute_with_default(data, attribute, prefix, external_source_id, default)
        #   value = value_of_attribute(data, attribute, prefix, external_source_id)
        #   value = DataCycleCore::Classification.where(external_key: prefix + default, external_source_id: external_source_id)&.ids if value.blank?
        #   value
        # end

        # def self.value_of_attribute(data, attribute, prefix, external_source_id)
        #   value = data.detect { |i| i.dig('id') == "StringAttribute_#{attribute}" }&.dig('properties', 'stringvalue')
        #   value = DataCycleCore::Classification.where(external_key: prefix + value, external_source_id: external_source_id)&.ids if value.present?
        #   value.presence
        # end

        def self.parse_external_id(data)
          # if the feature was created in dataCycle, then sent to GIP via the Communicator and is now reimported, its
          # external_key was set internally to the thing ID and we need to set the correct external_key for the
          # importer to find it.
          fdb_id = data&.dig('properties', 'attributes')&.detect { |i| i.dig('id') == 'StringAttribute_att11' }&.dig('properties', 'stringvalue')
          return data.dig('id') if fdb_id.nil?

          content = DataCycleCore::Thing.find_by(id: fdb_id)
          if content.present? && content.external_key == fdb_id
            content.external_key = data.dig('id')
            content.save
          end

          data.dig('id')
        end

        def self.parse_section(geometry)
          return nil if geometry.blank? || geometry.dig('coordinates').blank? || geometry.dig('SRID').blank?
          return if geometry.dig('SRID') != 31_256 # Österreich Ost
          factory_source_projection = RGeo::CoordSys::Proj4.new('EPSG:31256')
          factory_source = RGeo::Cartesian.factory(srid: 31_256, proj4: factory_source_projection)
          longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
          longlat = RGeo::Cartesian.factory(srid: 4326, proj4: longlat_projection, has_z_coordinate: true)

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

        def self.parse_owner(data)
          owner = data.dig('properties', 'objectid')&.digits&.last
          return Array.wrap("Gip - DATABASE - #{owner}") unless owner.nil?
          []
        end

        def self.load_feature_routes(route_id, external_source_id)
          return [] if route_id.blank?

          DataCycleCore::Thing.where(external_key: "GeoName_#{route_id}", external_source_id: external_source_id)&.ids
        end
      end
    end
  end
end
