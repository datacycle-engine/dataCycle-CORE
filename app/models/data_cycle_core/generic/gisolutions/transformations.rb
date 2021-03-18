# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gisolutions
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_lift(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'Gisolutions - Lift - ' + s.dig('id_gisolutions').to_s })
          .>> t(:add_field, 'name', ->(s) { s.dig('prim_name') || '__NO_NAME__' })
          .>> t(:add_field, 'description', ->(s) { s.dig('ski_area_gisolutions') })
          .>> t(:add_field, 'line', ->(s) { geometry(s.dig('geometry')) })
          .>> t(:add_field, 'length', ->(s) { s.dig('length_2d') })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Kategorie - Lift - ', s.dig('kategorie'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Unterkategorie - Lift - ', s.dig('unterkat'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Kategorie - ', s.dig('kat_gisolutions'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bundesland - ', s.dig('state'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bezirk - ', s.dig('district'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Gemeinde - ', s.dig('commune'), external_source_id) })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.to_slope(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'Gisolutions - Piste - ' + s.dig('id_gisolutions').to_s })
          .>> t(:add_field, 'name', ->(s) { s.dig('prim_name') || '__NO_NAME__' })
          .>> t(:add_field, 'description', ->(s) { s.dig('ski_area_gisolution') })
          .>> t(:add_field, 'line', ->(s) { geometry(s.dig('geometry')) })
          .>> t(:add_field, 'length', ->(s) { s.dig('length_2d') })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Kategorie - Piste - ', s.dig('kategorie'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Unterkategorie - Piste - ', s.dig('unterkat'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Schwierigkeitsgrad - Piste - ', s.dig('difficulty_osm'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Pistenpflege - ', s.dig('grooming_osm'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Pistentyp - ', s.dig('type_osm'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bundesland - ', s.dig('state'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bezirk - ', s.dig('district'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Gemeinde - ', s.dig('commune'), external_source_id) })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.lookup(prefix, key, external_source_id)
          return [] if key.blank?
          DataCycleCore::Classification.where(external_key: prefix + key, external_source_id: external_source_id)&.ids
        end

        def self.geometry(geometry)
          return nil if geometry.blank?
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          factory.parse_wkt(geometry)
        end
      end
    end
  end
end
