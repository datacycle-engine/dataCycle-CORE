# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gisolutions
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_snow_resort
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Gisolutions - Skigebiet - #{s.dig('name')}" })
          .>> t(:reject_keys, ['id'])
          .>> t(:reject_keys, ['geometry', 'geom', 'kategorie', 'state', 'district', 'date', 'nr', 'region'])
        end

        def self.to_lift(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'Gisolutions - Lift - ' + s.dig('id_gisolutions').to_s })
          .>> t(:add_field, 'name', ->(s) { s.dig('prim_name') || '__NO_NAME__' })
          .>> t(:add_field, 'line', ->(s) { geometry(s.dig('geometry')) })
          .>> t(:add_field, 'length', ->(s) { s.dig('length_2d') })
          .>> t(:add_field, 'man_per_t', ->(s) { s.dig('man_per_t')&.to_f })
          .>> t(:add_field, 'man_per_h', ->(s) { s.dig('man_per_h')&.to_f })
          .>> t(:add_field, 'order_string', ->(s) { s.dig('nr') })
          .>> t(:add_links, 'snow_resort', DataCycleCore::Thing, external_source_id, ->(s) { ["Gisolutions - Skigebiet - #{s.dig('ski_area_gisolutions')}"] })
          .>> t(:add_field, 'ski_lift_type', ->(s) { lift_type_lookup(s.dig('kategorie'), s.dig('unterkat') || s.dig('unterkategorie')) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Kategorie - Lift - ', s.dig('kategorie'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Unterkategorie - Lift - ', s.dig('unterkat'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Kategorie - ', s.dig('kat_gisolutions'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bundesland - ', s.dig('state'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bezirk - ', s.dig('district'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Gemeinde - ', s.dig('commune'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Region - ', s.dig('region'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Land - ', s.dig('country'), external_source_id) })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.to_slope(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'Gisolutions - Piste - ' + s.dig('id_gisolutions').to_s })
          .>> t(:add_field, 'name', ->(s) { s.dig('prim_name') || '__NO_NAME__' })
          .>> t(:add_field, 'line', ->(s) { geometry(s.dig('geometry')) })
          .>> t(:add_field, 'length', ->(s) { s.dig('length_2d').is_a?(::String) ? s.dig('length_2d')&.to_f : s.dig('length_2d') })
          .>> t(:add_field, 'order_string', ->(s) { s.dig('nr') })
          .>> t(:add_links, 'snow_resort', DataCycleCore::Thing, external_source_id, ->(s) { ["Gisolutions - Skigebiet - #{s.dig('ski_area_gisolutions')}"] })
          .>> t(:add_field, 'ski_slope_difficulty', ->(s) { slope_difficulty(s.dig('difficulty_osm')) })
          .>> t(:add_field, 'ski_slope_type', ->(s) { slope_grooming(s.dig('grooming_osm')) })
          .>> t(:universal_classifications, ->(s) { lookup_bool(s, 'artif_snow', external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup_bool(s, 'floodlight', external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Kategorie - Piste - ', s.dig('kategorie'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Unterkategorie - Piste - ', s.dig('unterkat'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Schwierigkeitsgrad - Piste - ', s.dig('difficulty_osm'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Pistenpflege - ', s.dig('grooming_osm'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Pistentyp - ', s.dig('type_osm'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bundesland - ', s.dig('state'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Bezirk - ', s.dig('district'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Gemeinde - ', s.dig('commune'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Region - ', s.dig('region'), external_source_id) })
          .>> t(:universal_classifications, ->(s) { lookup('Gisolutions - Land - ', s.dig('country'), external_source_id) })
          .>> t(:reject_keys, ['id'])
          .>> t(:strip_all)
        end

        def self.slope_difficulty(difficulty)
          return [] if difficulty.blank?
          lookup_hash = {
            'easy' => 'odta:Easy',
            'intermediate' => 'odta:Medium',
            'advanced' => 'odta:Hard'
          }
          DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeDifficulty', lookup_hash[difficulty])
        end

        def self.slope_grooming(type)
          return [] if type.blank?
          lookup_hash = {
            'mogul' => 'odta:MogulSlope',
            'backcountry' => 'odta:SkiRoute',
            'classic' => 'odta:PracticeSlope'
          }
          DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiSlopeType', lookup_hash[type])
        end

        def self.lift_type_lookup(kategorie, unterkategorie)
          return [] if kategorie.blank? && unterkategorie.blank?
          key = unterkategorie || kategorie
          lookup_hash = {
            '1-Seil-Umlaufbahn-Gondelbahn' => 'odta:CableCar',
            'Kabinenbahn, Umlaufseilbahn' => 'odta:CableCar',
            'Kombination Gondel/Sessel' => 'odta:ChairLift',
            'Mehrseil-Umlaufbahn-Gondelbahn' => 'odta:CableCar',
            'Pendelbahn, Großkabinenbahn' => 'odta:CableCar',
            'Sesselbahn' => 'odta:ChairLift',
            'Seilbahn' => 'odta:CableCar',
            'Seilbahn, Schwebebahn' => 'odta:CableCar',
            'Schlepplift' => 'odta:TBarLift',
            'Förderband' => 'odta:MagicCarpet',
            'J-Bar Lift' => 'odta:PracticeLift',
            'Seil-Zuglift' => 'odta:RopeTow',
            'Ski-, Schlepplift' => 'odta:TBarLift',
            'T-Bar Lift' => 'odta:TBarLift',
            'Tellerlift' => 'odta:PracticeLift'
          }
          DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('odta:SkiLiftType', lookup_hash[key] || lookup_hash[kategorie])
        end

        def self.lookup(prefix, key, external_source_id)
          return [] if key.blank?
          DataCycleCore::Classification.where(external_key: prefix + key, external_source_id: external_source_id)&.ids
        end

        def self.lookup_bool(data, key, external_source_id)
          return [] unless data[key] == 'yes'
          DataCycleCore::Classification.where(external_key: 'Gisolutions - Pistenausstattung - ' + key, external_source_id: external_source_id)&.ids
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
