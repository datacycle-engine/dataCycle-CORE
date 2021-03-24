# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_slope(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Piste - #{s.dig('ski_region_id')} - #{s.dig('c')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('st')}", external_source_id: external_source_id)&.ids })
          .>> t(:universal_classifications, ->(s) { DataCycleCore::Classification.where(external_key: "Feratel Webcams - Unterkategorie - #{s.dig('typ')}", external_source_id: external_source_id)&.ids })
          .>> t(:strip_all)
        end

        def self.to_lift(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Lift - #{s.dig('ski_region_id')} - #{s.dig('c')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
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
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Schigebiet - #{s.dig('rid').downcase}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
          .>> t(:add_links, 'lifts', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where("external_key ILIKE 'Feratel Webcams - Lift - #{s.dig('rid').downcase} - %' AND external_source_id = '#{external_source_id}'")&.pluck(:external_key) })
          .>> t(:add_links, 'slopes', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where("external_key ILIKE 'Feratel Webcams - Piste - #{s.dig('rid').downcase} - %' AND external_source_id = '#{external_source_id}'")&.pluck(:external_key) })
          .>> t(:add_links, 'amenity_feature', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where("external_key ILIKE 'Feratel Webcams - Zusatzangebot - #{s.dig('rid').downcase} - %' AND external_source_id = '#{external_source_id}'")&.pluck(:external_key) })
          .>> t(:strip_all)
        end
      end
    end
  end
end
