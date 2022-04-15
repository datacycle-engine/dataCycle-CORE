# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Toubiz
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.add_contact_info(data)
          contact_info = {}
          contact_info['url'] = data.dig('contactInformation', 'website')

          numbers = data.dig('phoneNumbers').select { |i| i['type'].in?(['mobile', 'phone']) }
          numbers = numbers.select { |i| i['primary'] == true } if numbers.size > 1
          contact_info['telephone'] = numbers&.first&.dig('iso5008')

          numbers = data.dig('phoneNumbers').select { |i| i['type'].in?(['fax']) }
          numbers = numbers.select { |i| i['primary'] == true } if numbers.size > 1
          contact_info['fax_number'] = numbers&.first&.dig('iso5008')

          email = data.dig('emails').detect { |i| i['primary'] == true }.presence || data.dig('emails')&.first
          contact_info['email'] = email&.dig('email')

          name = [data.dig('contactInformation', 'contactPersonFirstName'), data.dig('contactInformation', 'contactPersonLastName')].join(' ').strip.presence
          contact_info['contact_name'] = name

          data['contact_info'] = contact_info
          data
        end

        def self.add_info(data, external_source_id, field_names)
          additional_information = field_names
            .select { |type| data[type].strip.present? }
            .map { |type| { 'name' => type, 'description' => data[type] } }
            .map { |text|
              type = text['name']
              external_key = "mein.toubiz - AdditionalInformation - #{data.dig('external_key')} - #{type}"
              {
                'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
                'external_key' => external_key,
                'name' => I18n.t("import.toubiz.#{type}", default: [type]),
                'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)),
                'description' => text['description']
              }
            }.compact
          data['additional_information'] = additional_information
          data
        end

        def self.add_ccc(data)
          return data if data.dig('license').blank? || !data.dig('license').starts_with?('cc')
          key = data.dig('license').upcase.split('-')
          data['license_classification'] = DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Lizenzen', "#{key[0]} #{key[1..-1].join('-')}")
          data
        end

        def self.add_tour(data)
          points = data.dig('tour', 'points')
          return data if points.blank?
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          data['line'] = factory.multi_line_string(
            [factory.line_string(points.map { |point| factory.point(point[1], point[0], point[2]) })]
          )
          data
        end
      end
    end
  end
end
