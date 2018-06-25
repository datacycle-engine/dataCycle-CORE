# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Feratel::TransformationFunctions[*args]
        end

        def self.feratel_to_accommodation(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
            .>> t(:flatten_translations)
            .>> t(:flatten_texts)
            .>> t(:unwrap, 'Details')
            .>> t(:rename_keys,
              'Id' => 'external_key',
              'Names' => 'name')
            .>> t(:unwrap, 'Position')
            .>> t(:rename_keys,
              'Latitude' => 'latitude',
              'Longitude' => 'longitude')
            .>> t(:map_value, 'latitude', ->(v) { v.to_f })
            .>> t(:map_value, 'longitude', ->(v) { v.to_f })
            .>> t(:location)
            .>> t(:unwrap_description, 'ServiceProviderDescription')
            .>> t(:rename_keys, 'ServiceProviderDescription' => 'description')
            .>> t(:reject_keys, ['Town'])
            .>> t(:unwrap_address, 'Object')
            .>> t(:unwrap, 'Address')
            .>> t(:rename_keys,
              'AddressLine1' => 'street_address',
              'Town' => 'address_locality',
              'ZipCode' => 'postal_code',
              'Country' => 'address_country',
              'Fax' => 'fax_number',
              'Phone' => 'telephone',
              'Email' => 'email',
              'URL' => 'url')
            .>> t(:add_links, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('Documents', 'Document')&.flatten&.reject(&:nil?)&.select{ |d| d['Class'] == 'Image'}&.map { |item| item&.dig('id') } || [] })
            .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'HolidayThemes', 'Item')&.flatten&.reject(&:nil?)&.map { |item| item&.dig('id') } || [] })
            .>> t(:add_links, 'accommodation_categories', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Categories', 'Item')&.flatten&.reject(&:nil?)&.map { |item| item&.dig('id') } || [] })
            .>> t(:add_links, 'feratel_classifications', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Classifications', 'Item')&.flatten&.reject(&:nil?)&.map { |item| item&.dig('id') } || [] })
            .>> t(:add_links, 'stars', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Stars')&.flatten&.reject(&:nil?)&.map { |item| item&.dig('id') } || [] })
            .>> t(:map_value, 'url', ->(s) { s.nil? ? '' : (!s.starts_with?('http://') && !s.starts_with?('https://') ? "http://#{s}" : s) })
            .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
            .>> t(:nest, 'contact_info', ['email', 'fax_number', 'telephone', 'url'])
        end

        def self.feratel_to_image
          t(:stringify_keys)
          .>> t(:add_field, 'headline', ->(s) { s.dig('Names', 'Translation', 'text') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('URL').is_a?(String) ? s.dig('URL') : s.dig('URL', 'text') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('URL').is_a?(String) ? s.dig('URL') : s.dig('URL', 'text') })
          .>> t(:rename_keys, { 'Id' => 'external_key', 'Width' => 'width', 'Height' => 'height', 'Size' => 'content_size', 'Extension' => 'file_format' })
          .>> t(:map_value, 'width', ->(v) { v.to_i })
          .>> t(:map_value, 'height', ->(v) { v.to_i })
          .>> t(:map_value, 'content_size', ->(v) { v.to_i })
          .>> t(:reject_keys, ['Type', 'Class', 'Systems', 'Order', 'ShowFrom', 'ShowTo', 'ChangeDate', 'Systems', 'Systems', 'Names'])
          .>> t(:strip_all)
        end
      end
    end
  end
end
