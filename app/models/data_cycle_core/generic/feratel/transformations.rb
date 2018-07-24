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
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:unwrap, 'Position')
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude')
          .>> t(:map_value, 'latitude', ->(v) { v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.to_f })
          .>> t(:location)
          .>> t(:unwrap_description, 'ServiceProviderDescription')
          .>> t(:rename_keys, 'ServiceProviderDescription' => 'description')
          .>> t(:reject_keys, ['Town'])
          .>> t(:unwrap_address, 'Object')
          .>> t(:unwrap, 'Address')
          .>> t(
            :rename_keys,
            {
              'AddressLine1' => 'street_address',
              'Town' => 'address_locality',
              'ZipCode' => 'postal_code',
              'Country' => 'address_country',
              'Fax' => 'fax_number',
              'Phone' => 'telephone',
              'Email' => 'email',
              'URL' => 'url'
            }
          )
          .>> t(:add_links, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('Documents', 'Document')&.select { |d| d['Class'] == 'Image' }&.map { |item| item&.dig('Id') } || [] })
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'accommodation_categories', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Categories', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_classifications', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Classifications', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'stars', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Stars')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('DataOwner')).hexdigest}"] : [] })
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

        def self.feratel_to_infrastructure(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:unwrap_description, 'InfrastructureLong')
          .>> t(:unwrap_description, 'InfrastructureShort')
          .>> t(:add_field, 'description', ->(v) { v&.dig('InfrastructureLong') || v&.dig('InfrastructureShort') })
          .>> t(:unwrap_address, 'InfrastructureExternal')
          .>> t(:unwrap, 'Address', ['AddressLine1', 'Town', 'ZipCode', 'Country', 'Fax', 'Phone', 'Email', 'URL'])
          .>> t(
            :rename_keys,
            {
              'AddressLine1' => 'street_address',
              'Town' => 'address_locality',
              'ZipCode' => 'postal_code',
              'Country' => 'address_country',
              'Fax' => 'fax_number',
              'Phone' => 'telephone',
              'Email' => 'email',
              'URL' => 'url'
            }
          )
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'address_country', 'postal_code'])
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'email', 'url'])
          .>> t(:unwrap, 'Position')
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude')
          .>> t(:map_value, 'latitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:location)
          .>> t(:add_field, 'opening_hours_specification', ->(s) { parse_opening_hours(s.dig('OpeningHours', 'OpeningHour')) })
          .>> t(:add_links, 'image', DataCycleCore::CreativeWork, external_source_id, ->(s) { s&.dig('Documents', 'Document')&.select { |d| d['Class'] == 'Image' }&.map { |item| item&.dig('Id') } || [] })
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('DataOwner')).hexdigest}"] : [] })
          .>> t(:add_links, 'feratel_topics', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Topics', 'Topic')]&.flatten&.map { |item| item&.dig('Id') } || [] })
          .>> t(:load_category_key, 'feratel_types', external_source_id, ->(v) { v&.dig('Topics', 'Type') })
          .>> t(:reject_keys, ['Links', 'OpeningHours', 'Towns', 'CustomAttributes', 'FoodAndBeverage', 'ConnectedEntries', 'HolidayThemes', 'DataOwner', 'Active', 'Address', 'Topics', 'ChangeDate', 'Systems', '_Type'])
          .>> t(:strip_all)
        end

        def self.parse_opening_hours(data)
          return nil if data.blank?
          data = [data] if data.is_a?(::Hash)
          data.map do |item|
            day_keys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map do |day|
              next unless item&.dig(day) == 'true'
              load_day_of_week_id(day)
            end
            {
              validity: {
                valid_from: item.dig('DateFrom'),
                valid_through: item.dig('DateTo')
              },
              opens: item.dig('TimeFrom'),
              closes: item.dig('TimeTo'),
              day_of_week: day_keys
            }.with_indifferent_access
          end
        end

        def self.load_day_of_week_id(day)
          return nil unless ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].include?(day)
          day_hash = {
            'Mon' => 'Montag',
            'Tue' => 'Dienstag',
            'Wed' => 'Mittwoch',
            'Thu' => 'Donnerstag',
            'Fri' => 'Freitag',
            'Sat' => 'Samstag',
            'Sun' => 'Sonntag'
          }
          DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
            .where('classification_tree_labels.name = ?', 'Wochentage')
            .where('classification_aliases.name = ?', day_hash[day]).first!.id
        end
      end
    end
  end
end
