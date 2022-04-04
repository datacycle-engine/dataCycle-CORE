# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ImxPlatform
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.locale_string(data, name, property)
          return data if data.dig(*Array.wrap(property)).blank?
          data[name] = data.dig(*Array.wrap(property), I18n.locale.to_s)
          data
        end

        def self.parse_geo(data)
          latitude = data
            .dig('geoInfo', 'coordinates', 'latitude')
            &.to_f
            &.then { |i| i.zero? ? nil : i }
          longitude = data
            .dig('geoInfo', 'coordinates', 'longitude')
            &.to_f
            &.then { |i| i.zero? ? nil : i }
          if latitude.blank?
            latitude = data
              .dig('location', 'coorinates', 'latitude')
              &.to_f
              &.then { |i| i.zero? ? nil : i }
          end
          if longitude.blank?
            longitude = data
              .dig('location', 'coorinates', 'longitude')
              &.to_f
              &.then { |i| i.zero? ? nil : i }
          end
          data['latitude'] = latitude
          data['longitude'] = longitude
          data
        end

        def self.add_info(data, fields, external_source_id)
          additional_information = fields.map { |type|
            next if data[type].blank?
            external_key = "ImxPlatform - AdditionalInformation - #{data.dig('id')} - #{type}"
            {
              'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
              'external_key' => external_key,
              'name' => I18n.t("import.imx_platform.#{type}", default: [type]),
              'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', type)),
              'description' => data[type]
            }.compact
          }.compact
          data['additional_information'] = additional_information
          data
        end

        def self.parse_contact(data)
          contact_data = data.dig('contact1') if data.dig('contact1', 'contactName').present?
          contact_data ||= data.dig('contact2') if data.dig('contact2', 'contactName').present?
          return data if contact_data['contactName'].blank?
          contact_info = {}
          contact_info['name'] = contact_data['contactName']
          contact_info['telephone'] = contact_data.dig('address', 'phone1') || contact_data.dig('address', 'phone2')
          contact_info['fax_number'] = contact_data.dig('address', 'fax')
          contact_info['email'] = contact_data.dig('address', 'email')
          contact_info['url'] =
            if contact_data.dig('address', 'homepage').is_a?(::Hash)
              contact_data.dig('address', 'homepage', I18n.locale.to_s)
            else
              contact_data.dig('address', 'homepage')
            end
          data['contact_info'] = contact_info
          address = {}
          address['street_address'] = [contact_data.dig('address', 'street'), contact_data.dig('address', 'streetNo')].join(' ')
          address['postal_code'] = contact_data.dig('address', 'zipcode') if contact_data.dig('address', 'zipcode').present? && contact_data.dig('address', 'zipcode') != '*****'
          address['address_locality'] = contact_data.dig('address', 'city')
          data['address'] = address
          data
        end

        def self.add_images(data, external_source_id)
          images = data
            .dig('media')
            .map { |i| { id: i['id'], sort: i['sortingValue'] } }
            .sort_by { |i| i[:sort] }
            .map { |i| "ImxPlatform - AddressbaseImage - #{i[:id]}" }
            .map { |i| DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: i)&.id }
            .compact
          data['image'] = images
          data
        end
      end
    end
  end
end
