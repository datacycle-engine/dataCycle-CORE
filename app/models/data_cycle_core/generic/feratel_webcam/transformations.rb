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
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Schigebiet - #{s.dig('rid')}" })
          .>> t(:add_field, 'name', ->(s) { s.dig('c') || '__NO_NAME__' })
          .>> t(:add_links, 'lifts', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where('external_key ILIKE ? AND external_source_id = ?', "Feratel Webcams - Lift - #{s.dig('rid').downcase} - %", external_source_id)&.pluck(:external_key) })
          .>> t(:add_links, 'slopes', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where('external_key ILIKE ? AND external_source_id = ?', "Feratel Webcams - Piste - #{s.dig('rid').downcase} - %", external_source_id)&.pluck(:external_key) })
          .>> t(:add_links, 'amenity_feature', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where('external_key ILIKE ? AND external_source_id = ?', "Feratel Webcams - Zusatzangebot - #{s.dig('rid').downcase} - %", external_source_id)&.pluck(:external_key) })
          .>> t(:strip_all)
        end

        def self.to_image
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Image - #{s.dig('type')} - #{s.dig('rid')}" })
          .>> t(:add_field, 'name', ->(s) { "Bild Webcam #{s.dig('type') == 'is' ? 'Highlight' : 'Aktuell'}" })
          .>> t(:hashify_data, 'isi')
          .>> t(:hashify_data, 'hi')
          .>> t(:add_field, 'content_url', ->(s) { s.dig("#{s.dig('type')}i", '36', s.dig('url_key')) })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig("#{s.dig('type')}i", '44', s.dig('url_key')) })
        end

        def self.to_weather_station(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { "Feratel Webcams - Wetterstation - #{s.dig('rid')}" })
          .>> t(:hashify_data, 'pci')
          .>> t(:add_field, 'elevation', ->(s) { s.dig('pci', '5')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('pci', '8')&.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('pci', '7')&.to_f })
          .>> t(:location)
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('pci', '3')&.in_time_zone })
          .>> t(:add_field, 'url', ->(s) { s.dig('pci', '20') })
          .>> t(:add_field, 'email', ->(s) { s.dig('pci', '21') })
          .>> t(:add_field, 'telephone', ->(s) { s.dig('pci', '23') })
          .>> t(:nest, 'contact_info', ['telephone', 'url', 'email'])
          .>> t(:add_field, 'name', ->(s) { s.dig('pci', '1') || s.dig('pci', '2') || s.dig('pci', '4') })
          .>> t(:add_field, 'url', ->(s) { s.dig('pci', '26', 'v') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { ["Feratel Webcams - Image - is - #{s.dig('rid')}", "Feratel Webcams - Image - h - #{s.dig('rid')}"] })
        end

        def self.debug(data)
          # byebug
        end
      end
    end
  end
end
