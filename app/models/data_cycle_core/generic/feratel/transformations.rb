# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Feratel::TransformationFunctions[*args]
        end

        def self.to_brochure(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_cc, external_source_id)
          .>> t(:add_field, 'order', ->(s) { s.dig('Details', 'Order')&.to_i })
          .>> t(:rename_keys, 'Id' => 'external_key')
          .>> t(:add_field, 'name', ->(s) { s.dig('Details', 'Names') || s.dig('Details', 'Name') })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['ShopItem']))
          .>> t(:reject_keys, ['Names', 'Name'])
          .>> t(:add_field, 'work_translation', ->(s) { Array.wrap(s.dig('Variations', 'Variation')).map { |variation| to_variation(external_source_id).call(variation) } })
          .>> t(:unwrap_description, 'ShopItemDescription')
          .>> t(:add_field, 'potential_action', ->(s) { parse_links(s.dig('Links', 'Link'), external_source_id) })
          .>> t(:add_field, 'url', ->(s) { parse_url(Array.wrap(s.dig('Links', 'Link')).first&.dig('URL')) })
          .>> t(:add_field, 'description', ->(s) { parse_description(s) })
          .>> t(:universal_classifications, ->(s) { load_active(s.dig('Details', 'Active')) })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Owner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('Details', 'Owner')).hexdigest}"] : [] })
          .>> t(:universal_classifications, ->(s) { s.dig('feratel_owners') })
          .>> t(:add_links, 'feratel_shop_item_groups', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Group', 'Id').present? ? [s&.dig('Details', 'Group', 'Id')&.downcase] : [] })
          .>> t(:universal_classifications, ->(s) { s.dig('feratel_shop_item_groups') })
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Details', 'HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('holiday_themes') })
          .>> t(:add_links, 'language_variations', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('Variations', 'Variation')).map { |i| i.dig('Details', 'Language') }.compact.map { |i| "Feratel - Sprachvariante - #{i}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('language_variations') })
          .>> t(:reject_keys, ['ShopItemDescription', 'feratel_owners', 'feratel_shop_item_groups', 'holiday_themes', 'language_variations', 'Documents', 'Descriptions', 'Links', 'Variations', 'Details', 'HolidayThemes', 'feratel_documents'])
          .>> t(:strip_all)
        end

        def self.parse_description(s)
          variation_description = Array.wrap(s.dig('Variations', 'Variation'))
            .select { |i| i.dig('Descriptions', 'Description').present? && i.dig('Details', 'Language') == I18n.locale.to_s }
            &.first
          variation_description = Array.wrap(variation_description.dig('Descriptions', 'Description'))&.first&.dig('text') if variation_description.present?
          main_description = DataCycleCore::Utility::Sanitize::String.format_html(s&.dig('ShopItemDescription'))
          main_description.presence || DataCycleCore::Utility::Sanitize::String.format_html(variation_description).presence
        end

        def self.to_variation(external_source_id)
          t(:add_field, 'id', ->(s) { DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: s.dig('Id'))&.id })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['ShopItemVariation']))
          .>> t(:add_field, 'potential_action', ->(s) { parse_links(s.dig('Links', 'Link'), external_source_id) })
          .>> t(:rename_keys, 'Id' => 'external_key')
          .>> t(:add_field, 'url', ->(s) { parse_url(Array.wrap(s.dig('Links', 'Link')).first&.dig('URL')) })
          .>> t(:add_field, 'variant_name', ->(s) { Array.wrap(s.dig('Documents', 'Document')).first&.dig('Names') }) # for whatever reason can be more than one ...
          .>> t(:add_field, 'variant_language_abbr', ->(s) { s.dig('Details', 'Language') })
          .>> t(:add_field, 'variant_language', ->(s) { I18n.t("locales.#{s.dig('Details', 'Language').downcase}", default: nil) })
          .>> t(:add_field, 'stock', ->(s) { s.dig('Details', 'Stock')&.to_i })
          .>> t(:add_field, 'weight', ->(s) { s.dig('Details', 'Weight') })
          .>> t(:reject_keys, ['Documents', 'Links', 'Details'])
          .>> t(:compact)
        end

        def self.get_variation_link(data)
          if I18n.locale == :de
            link_data = Array.wrap(data.dig('Links', 'Link')).first
          else
            link_data = Array.wrap(data.dig('Variations', 'Variation'))
              .detect { |i| i.dig('Details', 'Language') == I18n.locale.to_s }
              &.dig('Links', 'Link')
          end
          return nil if link_data.blank? && DataCycleCore::Thing.find_by(external_key: "ViewLink:#{data['external_key']}").blank?
          link_data ||= {}
          link_data['Id'] = "ViewLink:#{data['external_key']}"
          link_data
        end

        def self.to_local_business(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_cc, external_source_id)
          .>> t(:rename_keys, 'Id' => 'external_key')
          .>> t(:add_field, 'additional_information', ->(s) { parse_descriptions(s.dig('Descriptions', 'Description'), external_source_id, 'accommodation') })
          .>> t(:add_field, 'name', ->(s) { s.dig('Details', 'Names') || s.dig('Details', 'Name') })
          .>> t(:transform_name, 'name')
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['Service']))
          .>> t(:reject_keys, ['Names', 'Name'])
          .>> t(:unwrap_address_data, 'Object', ->(s) { Array.wrap(s.dig('Addresses', 'Address')) })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('Address', 'AddressLine1') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('Address', 'Town') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('Address', 'ZipCode') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('Address', 'Country') })
          .>> t(:add_field, 'country_code', ->(s) { [DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Ländercodes', s.dig('Address', 'Country'))] })
          .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
          .>> t(:add_field, 'fax_number', ->(s) { s.dig('Address', 'Fax') })
          .>> t(:add_field, 'telephone', ->(s) { s.dig('Address', 'Phone') })
          .>> t(:add_field, 'email', ->(s) { s.dig('Address', 'Email') })
          .>> t(:add_field, 'url', ->(s) { parse_url(s.dig('Address', 'URL')) })
          .>> t(:nest, 'contact_info', ['email', 'fax_number', 'telephone', 'url'])
          .>> t(:reject_keys, ['Address'])
          .>> t(:add_field, 'currencies_accepted', ->(s) { s.dig('Details', 'CurrencyCode') })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Details', 'Active')) })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('Details', 'DataOwner')).hexdigest}"] : [] })
          .>> t(:add_field, 'content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:add_field, 'feratel_content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:add_links, 'feratel_facilities_additional_services', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Facilities', 'Facility')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:ensure_classification_tree, 'feratel_facilities_additional_services', 'Feratel - Merkmale - Services')
          .>> t(:add_links, 'marketing_groups', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Details', 'MarketingGroups', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_field, 'makes_offer', ->(s) { load_offers(s, external_source_id) })
          .>> t(:add_links, 'fdbcode', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('Details', 'DBCode'))&.flatten&.reject(&:nil?)&.map { |item| "Feratel - DBCode - #{item}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('fdbcode') })
          .>> t(:reject_keys, ['Link', 'Details', 'CustomAttributes', 'QualityDetails'])
          .>> t(:strip_all)
        end

        def self.load_offers(s, external_source_id)
          data = Array.wrap(s.dig('AdditionalServices', 'AdditionalService'))
            &.map { |item| item.merge({ 'Products' => Array.wrap(item.dig('Products', 'Product')) }) }
            &.map { |item| item.dig('Products').map { |product| product.merge({ 'service_id' => item.dig('Id') }) } }
            &.flatten
            &.compact
            &.map do |item|
              to_offer(external_source_id).call(item).merge({
                'id' => t(:find_thing_ids).call(external_system_id: external_source_id, external_key: item.dig('Id'), limit: 1).first
              }.compact)
            end
          data
        end

        def self.to_offer(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:rename_keys, { 'Id' => 'external_key' })
          .>> t(:add_links, 'item_offered', DataCycleCore::Thing, external_source_id, ->(s) { [s.dig('service_id')] })
          .>> t(:add_field, 'name', ->(s) { s.dig('Details', 'Name') })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Details', 'Active')) })
          .>> t(:unwrap_description, ['ProductDescription'])
          .>> t(:add_field, 'description', ->(v) { DataCycleCore::Utility::Sanitize::String.format_html(v&.dig('ProductDescription')) if v&.dig('ProductDescription').present? })
          .>> t(:add_field, 'price_specification', ->(s) { load_min_price(s, external_source_id) })
          .>> t(:strip_all)
        end
        # .>> t(:add_links, 'offered_by', DataCycleCore::Thing, external_source_id, ->(s) { [s.dig('provider_id')] })

        def self.load_min_price(s, external_source_id)
          external_key = "Price:#{s.dig('external_key')}"
          price_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: external_key, limit: 1).first
          min_price = Array.wrap(s.dig('PriceDetail', 'PriceTemplates', 'PriceTemplate'))
            .map { |i| Array.wrap(i.dig('Prices', 'Prices')) }.flatten
            .map { |i| Array.wrap(i.dig('PriceValue')) }.flatten
            .map { |i| i.dig('Price')&.to_f }
            .min

          data = {
            'min_price' => min_price,
            'external_key' => external_key
          }

          min_price.nil? ? [] : [data.merge({ 'id' => price_id }.compact)]
        end

        def self.to_additional_service(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_field, 'description', ->(s) { Array.wrap(s.dig('Descriptions', 'Description')).detect { |item| item['Type'] == 'ServiceDescription' }.try(:[], 'text') })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['Service']))
          .>> t(:add_service_description, 'meeting_point', 'Meeting Point')
          .>> t(:add_service_description, 'equipment', 'Equipment')
          .>> t(:add_service_description, 'requirements', 'Requirements')
          .>> t(:add_service_description, 'included_services', 'Included Services')
          .>> t(:add_service_description, 'difficulty', 'Difficulty')
          .>> t(:rename_keys, { 'Id' => 'external_key', 'AdditionalServiceDescription' => 'text' })
          .>> t(:remove_description, ['GuestCardClassification'])
          .>> t(:add_field, 'additional_information', ->(s) { parse_descriptions(s.dig('Descriptions', 'Description'), external_source_id, 'additional_service') })
          .>> t(:add_links, 'provider', DataCycleCore::Thing, external_source_id, ->(s) { [s.dig('provider_id')] })
          .>> t(:add_field, 'name', ->(s) { s.dig('Details', 'Name') })
          .>> t(:add_link, 'area_served', DataCycleCore::Thing, external_source_id, ->(s) { "meeting_point: #{s['external_key']}" })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Details', 'Active')) })
          .>> t(:add_links, 'feratel_additional_service_type', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('Details', 'AdditionalServiceTypes', 'Item'))&.map { |type| type.dig('Id')&.downcase }&.compact.presence || [] })
          .>> t(:add_links, 'feratel_guest_cards', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('GuestCards', 'GuestCard'))&.flatten&.reject(&:nil?)&.map { |item| "#{item&.dig('Id')&.downcase} - #{item&.dig('UsageType')}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('feratel_guest_cards') })
          .>> t(:add_field, 'feratel_guest_cards_descriptions', ->(s) { parse_guest_card_descriptions(Array.wrap(s&.dig('GuestCards', 'GuestCard'))&.flatten&.reject(&:nil?), s&.dig('external_key'), external_source_id) || [] })
          .>> t(:merge_array_values, 'additional_information', 'feratel_guest_cards_descriptions')
          .>> t(:add_links, 'feratel_facilities_additional_services', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Facilities', 'Facility')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:ensure_classification_tree, 'feratel_facilities_additional_services', 'Feratel - Merkmale - Services')
          .>> t(:add_field, 'hours_available', ->(s) { load_schedules(s.dig('Details'), external_source_id) }) # .>> t(:add_field, 'hours_available', ->(s) { load_event_schedules(s.dig('Details')) })
          .>> t(:strip_all)
        end

        def self.to_meeting_point
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_field, 'name', ->(s) { [s.dig('Details', 'Name'), I18n.t('import.feratel.meeting_point', default: ['Treffpunkt'])].join(' - ') })
          .>> t(:add_service_description, 'meeting_point', 'Meeting Point')
          .>> t(:rename_keys, { 'meeting_point' => 'description' })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('Details', 'Position', 'Longitude')&.to_f })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('Details', 'Position', 'Latitude')&.to_f })
          .>> t(:add_field, 'external_key', ->(s) { ['meeting_point: ', s.dig('Id')].join })
          .>> t(:location)
          .>> t(:strip_all)
        end

        def self.load_price(s, external_source_id)
          external_key = "Price:#{s.dig('external_key')}"
          price_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: external_key, limit: 1).first
          data = {
            'min_price' => s.dig('Price', 'Range', 'From')&.to_f,
            'max_price' => s.dig('Price', 'Range', 'To')&.to_f,
            'external_key' => external_key
          }

          [data.merge({ 'id' => price_id }.compact)]
        end

        def self.feratel_to_accommodation(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_field, 'potential_action', ->(s) { parse_links(s.dig('Links', 'Link'), external_source_id) })
          .>> t(:add_links, 'founder', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s.dig('Addresses', 'Address')).select { |i| i.dig('Type') == 'LandLord' }.map { |i| "LandLord:#{i.dig('Id')}" } })
          .>> t(:add_cc, external_source_id)
          .>> t(:map_value, 'GTCs', ->(s) { Array.wrap(s&.dig('GTC')).map { |i| i.merge({ 'Type' => 'GTC' }) } })
          .>> t(:add_field, 'additional_information', ->(s) { parse_descriptions(s.dig('Descriptions', 'Description'), external_source_id, 'accommodation') })
          .>> t(:add_field, 'gtc', ->(s) { parse_descriptions(s.dig('GTCs'), external_source_id, 'GTC') })
          .>> t(:merge_array_values, 'additional_information', 'gtc')
          .>> t(:unwrap_description, 'ServiceProviderDescription')
          .>> t(:add_field, 'description', ->(s) { DataCycleCore::Utility::Sanitize::String.format_html(s&.dig('ServiceProviderDescription')) })
          .>> t(:add_amenity_features, external_source_id)
          .>> t(:add_links, 'feratel_locations', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Town')&.yield_self { |town| town.is_a?(String) ? town : town['text'] } })
          .>> t(:add_links, 'fdbcode', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('Details', 'DBCode'))&.flatten&.reject(&:nil?)&.map { |item| "Feratel - DBCode - #{item}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('fdbcode') })
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:add_field, 'bookable', ->(s) { s&.dig('Bookable') == 'true' })
          .>> t(:transform_name, 'name')
          .>> t(:unwrap, 'Position')
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude')
          .>> t(:map_value, 'latitude', ->(v) { v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.to_f })
          .>> t(:location)
          .>> t(:reject_keys, ['Town'])
          .>> t(:unwrap_address_data, 'Object', ->(s) { Array.wrap(s.dig('Addresses', 'Address')) })
          .>> t(:unwrap, 'Address')
          .>> t(:rename_keys, { 'AddressLine1' => 'street_address', 'Town' => 'address_locality', 'ZipCode' => 'postal_code', 'Country' => 'address_country' })
          .>> t(:rename_keys, { 'Fax' => 'fax_number', 'Phone' => 'telephone', 'Email' => 'email', 'URL' => 'url' })
          .>> t(:add_external_system_data, ['MetaRating', 'RatingSystem'], ['MetaRating', 'RatingCode'])
          .>> t(:add_field, 'number_of_rooms', ->(s) { s.dig('Rooms')&.to_i })
          .>> t(:add_field, 'total_number_of_beds', ->(s) { s.dig('Beds')&.to_i })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['ServiceProvider']))
          .>> t(:add_links, 'logo', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['ServiceProviderLogo']))
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'accommodation_categories', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Categories', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_classifications', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Classifications', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'stars', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Stars')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('DataOwner')).hexdigest}"] : [] })
          .>> t(:add_links, 'feratel_facilities', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Facilities', 'Facility')]&.flatten&.reject(&:nil?)&.map { |item| "#{item&.dig('Id')&.downcase} - #{item&.dig('Value')}" } || [] })
          .>> t(:ensure_classification_tree, 'feratel_facilities', 'Feratel - Ausstattungsmerkmale')
          .>> t(:add_links, 'feratel_facilities_accommodations', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Facilities', 'Facility')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:ensure_classification_tree, 'feratel_facilities_accommodations', 'Feratel - Merkmale - Unterkünfte')
          .>> t(:universal_classifications, ->(s) { Array.wrap(s.dig('HandicapFacilities', 'HandicapFacility')).map { |facility| DataCycleCore::Classification.find_by(external_key: "Feratel - HandicapFacility - #{facility.dig('Id')}")&.id }.compact })
          .>> t(:add_links, 'marketing_groups', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('MarketingGroups', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Active')) })
          .>> t(:add_field, 'content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:add_field, 'feratel_content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:map_value, 'url', ->(s) { parse_url(s) })
          .>> t(:add_links, 'contains_place_service', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('Services', 'Service')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'contains_place_additional_service', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('AdditionalServices', 'AdditionalService')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_field, 'contains_place', ->(s) { s.dig('contains_place_service') + s.dig('contains_place_additional_service') })
          .>> t(:add_field, 'makes_offer_service', ->(s) { parse_products([s.dig('Services', 'Service')]&.flatten&.compact, external_source_id) })
          .>> t(:add_field, 'makes_offer_package', ->(s) { parse_packages([s.dig('HousePackageMasters', 'HousePackageMaster')]&.flatten&.compact, external_source_id) })
          .>> t(:add_field, 'makes_offer', ->(s) { Array(s.dig('makes_offer_package')) + Array(s.dig('makes_offer_service')) })
          .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
          .>> t(:nest, 'contact_info', ['email', 'fax_number', 'telephone', 'url'])
        end
        # to include services, offers, prices
        # !!!!! service -> offer embedded relation ist jetzt translated = true !!!!
        # .>> t(:add_links, 'contains_place_service', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('Services', 'Service')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
        # .>> t(:add_links, 'contains_place_additional_service', DataCycleCore::Thing, external_source_id, ->(s) { [s&.dig('AdditionalServices', 'AdditionalService')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
        # .>> t(:add_field, 'contains_place', ->(s) { s.dig('contains_place_service') + s.dig('contains_place_additional_service') })
        # .>> t(:add_field, 'makes_offer_service', ->(s) { parse_products([s.dig('Services', 'Service')]&.flatten&.compact, external_source_id) })
        # .>> t(:add_field, 'makes_offer_package', ->(s) { parse_packages([s.dig('HousePackageMasters', 'HousePackageMaster')]&.flatten&.compact, external_source_id) })
        # .>> t(:add_field, 'makes_offer', ->(s) { Array(s.dig('makes_offer_package')) + Array(s.dig('makes_offer_service')) })

        def self.parse_descriptions(data, external_source_id, type, additional_classifications = nil)
          return [] if data.blank?
          description_ids = [] # ids for descriptions are not uniq in Feratel DSI

          Array.wrap(data).map { |desc|
            next if description_ids.include?(desc.dig('Id')) || desc.dig('Type') == 'InfrastructureOpeningTimes'
            description_ids.push(desc.dig('Id'))
            to_additional_information(external_source_id, type, additional_classifications).call(desc)
          }.compact
        end

        def self.parse_opening_hours_descriptions(data, external_source_id)
          return [] if data.blank?
          description_ids = [] # ids for descriptions are not uniq in Feratel DSI

          Array.wrap(data).compact.filter { |d| d['Type'] == 'InfrastructureOpeningTimes' }.map { |desc|
            next if description_ids.include?(desc['Id'])
            description_ids.push(desc['Id'])

            old_type = DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: desc['Id'])

            if !old_type.nil? && old_type.embedded? && old_type.template_name != 'Öffnungszeit - Beschreibung'
              old_type.destroy_children(destroy_locale: false)
              old_type.destroy
            elsif !old_type.nil? && old_type.template_name == 'Öffnungszeit - Beschreibung'
              desc['id'] = old_type.id
            end

            to_opening_hours_description.call(desc)
          }.compact
        end

        def self.parse_url(url_string)
          return nil if url_string.nil?

          # get ridd of most common bullshit
          s = url_string&.squish
          s = s.delete(' ') if s.present?
          s = s[8..-1] if s.start_with?('http://?')

          if s.nil?
            ''
          elsif !s.starts_with?('http://') && !s.starts_with?('https://')
            "http://#{s}"
          else
            s
          end
        end

        def self.to_opening_hours_description
          t(:rename_keys, { 'text' => 'description' })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('ChangeDate').in_time_zone })
          .>> t(:add_field, 'validity_schedule', ->(s) { Array.wrap(s.dig('ShowFrom').is_a?(::Time) && s.dig('ShowTo').is_a?(::Time) ? make_term(s.dig('ShowFrom'), s.dig('ShowTo')) : make_season(s.dig('ShowFrom'), s.dig('ShowTo'))) })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('Id') })
          .>> t(:reject_keys, ['Id', 'Type', 'Language', 'Systems', 'ShowFrom', 'ShowTo', 'ChangeDate'])
        end

        def self.to_additional_information(external_source_id, type, additional_classifications = nil)
          t(:rename_keys, { 'text' => 'description' })
          .>> t(:add_cc, external_source_id)
          .>> t(:add_field, 'id', ->(s) { DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: s.dig('Id'))&.id })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('ChangeDate').in_time_zone })
          .>> t(:add_field, 'name', ->(s) { I18n.t("import.feratel.#{type}.#{s.dig('Name') || s.dig('Type')}", default: [s.dig('Name') || s.dig('Type')]) })
          .>> t(:universal_classifications, ->(s) { parse_system_letters(s.dig('Systems')) })
          .>> t(:universal_classifications, ->(s) { Array.wrap(s.dig('Type')).map { |desc| DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', desc) } })
          .>> t(:add_links, 'additional_classifications', DataCycleCore::Classification, external_source_id, ->(_s) { additional_classifications || [] })
          .>> t(:merge_array_values, 'universal_classifications', 'additional_classifications')
          .>> t(:merge_array_values, 'universal_classifications', 'feratel_creative_commons')
          .>> t(:add_field, 'validity_schedule', ->(s) { Array.wrap(s.dig('ShowFrom').is_a?(::Time) && s.dig('ShowTo').is_a?(::Time) ? make_term(s.dig('ShowFrom'), s.dig('ShowTo')) : make_season(s.dig('ShowFrom'), s.dig('ShowTo'))) })
          .>> t(:add_field, 'external_key', ->(s) { s.dig('Id') })
          .>> t(:reject_keys, ['Id', 'Type', 'Language', 'Systems', 'ShowFrom', 'ShowTo', 'ChangeDate'])
        end

        def self.make_season(from, to)
          raise ArgumentError if from.blank? || to.blank?
          return [] if from == '101' && to == '1231' # no schedule, is valid all year long
          from_date = Time.zone.local(2010, from.to_i / 100, from.to_i % 100, 0, 0)
          to_date = Time.zone.local(2010, to.to_i / 100, to.to_i % 100, 23, 59, 59).end_of_day
          to_date += 1.year if from_date > to_date
          from_yday = from_date.to_date.yday
          rrule = IceCube::Rule.yearly.day_of_year(from_yday)
          options = { end_time: to_date.end_of_day }
          schedule_object = IceCube::Schedule.new(from_date, options) do |s|
            s.add_recurrence_rule(rrule)
          end
          schedule_object.to_hash.merge(dtstart: from_date)
        end

        def self.make_term(from, to)
          raise ArgumentError if from.blank? || to.blank?
          options = { end_time: to }
          schedule_object = IceCube::Schedule.new(from, options)
          schedule_object.to_hash.merge(dtstart: from)
        end

        def self.parse_links(data, external_source_id)
          return [] if data.blank?
          Array.wrap(data).uniq.map { |link|
            next if link['URL'].blank? || link['URL'] == 'http://'
            to_view_action(external_source_id).call(link)
          }.compact
        end

        def self.to_view_action(external_source_id)
          t(:rename_keys, { 'URL' => 'url', 'Id' => 'external_key', 'Name' => 'name' })
          .>> t(:map_value, 'url', ->(s) { parse_url(s) })
          .>> t(:add_field, 'id', ->(s) { t(:find_thing_ids).call(external_system_id: external_source_id, external_key: s.dig('external_key'), limit: 1).first })
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('ChangeDate')&.in_time_zone })
          .>> t(:add_field, 'action_type', ->(_) { Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('ActionTypes', 'externer Link')) })
          .>> t(:reject_keys, ['ChangeDate', 'Type', 'Order', 'Names'])
        end

        def self.to_landlord(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:unwrap_description, 'AddressContactDescription')
          .>> t(:rename_keys, { 'AddressContactDescription' => 'description' })
          .>> t(:add_field, 'external_key', ->(s) { "LandLord:#{s.dig('Id')}" })
          .>> t(:reject_keys, ['Id'])
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('ChangeDate')&.in_time_zone })
          .>> t(:add_field, 'contact_name', ->(s) { [s.dig('Title'), s.dig('FirstName'), s.dig('LastName')].compact.join(' ').presence })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['AddressContactDocument']))
          .>> t(:rename_keys, { 'Fax' => 'fax_number', 'Phone' => 'telephone', 'Email' => 'email', 'URL' => 'url' })
          .>> t(:map_value, 'url', ->(s) { parse_url(s) })
          .>> t(:nest, 'contact_info', ['contact_name', 'email', 'fax_number', 'telephone', 'url'])
          .>> t(:rename_keys, { 'AddressLine1' => 'street_address', 'Town' => 'address_locality', 'ZipCode' => 'postal_code', 'Country' => 'address_country' })
          .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
          .>> t(:add_field, 'name', ->(s) { s.dig('Company') || [s.dig('Title'), s.dig('FirstName'), s.dig('LastName')].compact.join(' ').presence })
        end

        def self.to_organizer
          t(:flatten_texts)
          .>> t(:add_field, 'external_key', ->(s) { "Organizer:#{s.dig('Id')}" })
          .>> t(:reject_keys, ['Id'])
          .>> t(:add_field, 'date_modified', ->(s) { s.dig('ChangeDate')&.in_time_zone })
          .>> t(:add_field, 'contact_name', ->(s) { [s.dig('Title'), s.dig('FirstName'), s.dig('LastName')].compact.join(' ').presence })
          .>> t(:rename_keys, { 'Fax' => 'fax_number', 'Phone' => 'telephone', 'Email' => 'email', 'URL' => 'url' })
          .>> t(:map_value, 'url', ->(s) { parse_url(s) })
          .>> t(:nest, 'contact_info', ['contact_name', 'email', 'fax_number', 'telephone', 'url'])
          .>> t(:rename_keys, { 'AddressLine1' => 'street_address', 'Town' => 'address_locality', 'ZipCode' => 'postal_code', 'Country' => 'address_country' })
          .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
          .>> t(:add_field, 'name', ->(s) { s.dig('Company') || [s.dig('Title'), s.dig('FirstName'), s.dig('LastName')].compact.join(' ').presence })
        end

        def self.feratel_to_aggregate_offer(external_source_id)
          t(:recursion, t(:is, ::Hash, t(:stringify_keys)))
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_links, 'fdbcode', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('Details', 'DBCode'))&.flatten&.reject(&:nil?)&.map { |item| "Feratel - DBCode - #{item}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('fdbcode') })
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, { 'Id' => 'external_key', 'Name' => 'name' })
          .>> t(:add_field, 'additional_information', ->(s) { parse_descriptions(s.dig('Descriptions', 'Description'), external_source_id, 'package') })
          .>> t(:unwrap_description, ['Package', 'PackageShortText'])
          .>> t(:add_field, 'description', ->(s) { DataCycleCore::Utility::Sanitize::String.format_html(s&.dig('Package')) })
          .>> t(:add_field, 'text', ->(s) { DataCycleCore::Utility::Sanitize::String.format_html(s&.dig('PackageShortText')) })
          .>> t(:unwrap_content_description, ['PackageContentShort', 'PackageContentLong'])
          .>> t(:add_field, 'content_description', ->(s) { s&.dig('PackageContentShort').present? ? DataCycleCore::Utility::Sanitize::String.format_html(s&.dig('PackageContentShort')) : nil })
          .>> t(:add_field, 'content_text', ->(s) { s&.dig('PackageContentLong').present? ? DataCycleCore::Utility::Sanitize::String.format_html(s&.dig('PackageContentLong')) : nil })
          .>> t(:add_field, 'low_price', ->(s) { min_price(Array.wrap(s.dig('PackageCategories', 'PackageCategory'))) })
          .>> t(:add_field, 'offer_period', ->(s) { parse_period(s.dig('ValidDates')) })
          .>> t(:add_field, 'offers', ->(s) { parse_package_offers(Array.wrap(s.dig('PackageCategories', 'PackageCategory')), external_source_id) })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['Package']))
          .>> t(:add_links, 'eligable_region', DataCycleCore::Thing, external_source_id, ->(s) { ["PackagePlace:#{s.dig('external_key')}"] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Owner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('Owner')).hexdigest}"] : [] })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Active')) })
          .>> t(:add_links, 'feratel_locations', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Towns', 'Item', 'Id')].reject(&:blank?) })
          .>> t(:add_field, 'feratel_offer_status', ->(s) { load_offer_status(s.dig('Bookable', 'text')) })
          .>> t(:add_field, 'feratel_price_type', ->(s) { load_price_type(s.dig('Settings', 'PriceSettings', 'PriceType')) })
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('HolidayThemes', 'Item'))&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:strip_all)
        end

        def self.feratel_to_package_place
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(_s) { 'GeoCoordinates' })
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude', 'place_id' => 'external_key')
          .>> t(:map_value, 'latitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:location)
        end

        def self.feratel_to_image(external_source_id)
          t(:stringify_keys)
          .>> t(:add_cc, external_source_id)
          .>> t(:universal_classifications, ->(s) { parse_system_letters(s.dig('Systems')) })
          .>> t(:add_field, 'name', lambda { |s|
            s.dig('Names', 'Translation', 'text') || ">> NO NAME << (\##{s.dig('Id')})"
          })
          .>> t(:add_field, 'content_url', ->(s) { parse_url(s.dig('URL').is_a?(String) ? s.dig('URL') : s.dig('URL', 'text')) })
          .>> t(:add_field, 'thumbnail_url', ->(s) { parse_url(s.dig('URL').is_a?(String) ? s.dig('URL') : s.dig('URL', 'text')) })
          .>> t(:rename_keys, {
            'Id' => 'external_key',
            'Width' => 'width',
            'Height' => 'height',
            'Size' => 'content_size',
            'Extension' => 'file_format',
            'Copyright' => 'caption'
          })
          .>> t(:map_value, 'width', ->(v) { v.to_i })
          .>> t(:map_value, 'height', ->(v) { v.to_i })
          .>> t(:map_value, 'content_size', ->(v) { v.to_i.kilobytes })
          .>> t(:add_field, 'validity_schedule', ->(s) { Array.wrap(s.dig('ShowFrom').is_a?(::Time) && s.dig('ShowTo').is_a?(::Time) ? make_term(s.dig('ShowFrom'), s.dig('ShowTo')) : make_season(s.dig('ShowFrom'), s.dig('ShowTo'))) })
          .>> t(:reject_keys, ['Type', 'Class', 'Systems', 'Order', 'ShowFrom',
                               'ShowTo', 'ChangeDate', 'Systems', 'Systems', 'Names'])
          .>> t(:strip_all)
        end

        def self.feratel_event_location_to_place
          t(:stringify_keys)
          .>> t(:rename_keys, { 'Id' => 'external_key' })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('AddressLine1', 'text') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('ZipCode', 'text') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('Town', 'text') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('Country', 'text') })
          .>> t(:nest, 'address', ['street_address', 'address_country', 'address_locality', 'postal_code'])
          .>> t(:add_field, 'latitude', ->(s) { s.dig('Position', 'Latitude')&.to_f&.then { |v| v.zero? ? nil : v } })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('Position', 'Longitude')&.to_f&.then { |v| v.zero? ? nil : v } })
          .>> t(:location)
          .>> t(:add_field, 'contact_name',
                lambda do |s|
                  [
                    s.dig('Company', 'text'),
                    [s.dig('FirstName', 'text'), s.dig('LastName', 'text')].flatten.reject(&:blank?).presence&.join(' ')
                  ].reject(&:blank?).join(' - ')
                end)
          .>> t(:add_field, 'email', ->(s) { s.dig('Email', 'text') })
          .>> t(:add_field, 'url', ->(s) { parse_url(s.dig('URL', 'text')) })
          .>> t(:add_field, 'telephone', ->(s) { s.dig('Mobile', 'text') || s.dig('Phone', 'text') })
          .>> t(:add_field, 'fax_number', ->(s) { s.dig('Fax', 'text') })
          .>> t(:nest, 'contact_info', ['contact_name', 'email', 'fax_number', 'telephone', 'url'])
          .>> t(:add_field, 'name',
                lambda do |s|
                  [
                    s.dig('Location', 'Translation', 'text'),
                    s.dig('Company', 'text'),
                    [s.dig('FirstName', 'text'), s.dig('LastName', 'text')].flatten.reject(&:blank?).presence&.join(' ')
                  ].reject(&:blank?).first
                end)
          .>> t(:reject_keys, ['Type', 'ChangeDate', 'Company', 'AddressLine1', 'Country', 'ZipCode', 'Town', 'Location', 'Position'])
          .>> t(:strip_all)
        end

        def self.feratel_to_event(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_cc, external_source_id)
          .>> t(:add_field, 'content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:add_field, 'feratel_content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:add_links, 'linked_thing', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s.dig('Details', 'ConnectedEntries', 'ConnectedEntry'))&.flatten&.map { |item| item&.dig('Id') } || [] })
          .>> t(:add_field, 'dc_potential_action', ->(s) { parse_links(s.dig('Links', 'Link'), external_source_id) })
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:unwrap_description, ['EventHeader'])
          .>> t(:add_field, 'description', ->(v) { DataCycleCore::Utility::Sanitize::String.format_html(v&.dig('EventHeader')) if v&.dig('EventHeader').present? })
          .>> t(:remove_description, ['GuestCardClassification'])
          .>> t(:add_field, 'additional_information', ->(s) { parse_descriptions(s.dig('Descriptions', 'Description'), external_source_id, 'event') })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['EventHeader']))
          .>> t(:add_field, 'feratel_locations', ->(s) { s.dig('Addresses', 'Address').is_a?(Hash) ? [s.dig('Addresses', 'Address')] : s.dig('Addresses', 'Address') })
          .>> t(:add_link, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { "Location:#{s.dig('external_key')}" })
          .>> t(:add_field, 'feratel_super_events', ->(s) { s.dig('SerialEvents', 'SerialEvent').is_a?(Hash) ? [s.dig('SerialEvents', 'SerialEvent')] : s.dig('SerialEvents', 'SerialEvent') })
          .>> t(:add_links, 'super_event', DataCycleCore::Thing, external_source_id, ->(s) { s.dig('feratel_super_events')&.map { |e| e&.dig('Id') } })
          .>> t(:add_field, 'schedule', ->(s) { load_event_schedules(s, external_source_id) }) # deprecated as_of(16.3.2020)
          .>> t(:add_field, 'event_schedule', ->(s) { load_schedules(s, external_source_id) })
          .>> t(:add_field, 'feratel_event_tags', ->(s) { load_feratel_event_tags([s.dig('Visibility'), (s.dig('IsTopEvent') == 'true' ? 'Top-Event' : nil)]) })
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('DataOwner')).hexdigest}"] : [] })
          .>> t(:add_links, 'feratel_locations', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Towns', 'Item', 'Id')].reject(&:blank?) })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Active')) })
          .>> t(:add_field, 'connected_entries', ->(s) { s.dig('ConnectedEntries', 'ConnectedEntry').is_a?(Hash) ? [s.dig('ConnectedEntries', 'ConnectedEntry')] : s.dig('ConnectedEntries', 'ConnectedEntry') })
          .>> t(:add_links, 'feratel_facilities', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Facilities', 'Facility')]&.flatten&.reject(&:nil?)&.map { |item| "#{item&.dig('Id')&.downcase} - #{item&.dig('Value')}" } || [] })
          .>> t(:ensure_classification_tree, 'feratel_facilities', 'Feratel - Ausstattungsmerkmale')
          .>> t(:add_links, 'feratel_facilities_events', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Facilities', 'Facility')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:ensure_classification_tree, 'feratel_facilities_events', 'Feratel - Merkmale - Events')
          .>> t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id,
                lambda do |s|
                  [
                    s.dig('connected_entries')&.select { |c| c['Type'] == 'EventServiceProvider' }&.map { |c| c['Id'] },
                    s.dig('Addresses', 'Address')&.select { |c| c['Type'] == 'Organizer' }&.map { |c| "Organizer:#{c['Id']}" }
                  ].flatten.compact
                end,
                ->(s) { s.dig('connected_entries').present? || s.dig('Addresses', 'Address').present? })
          .>> t(:add_links, 'connected_location', DataCycleCore::Thing, external_source_id, ->(s) { s.dig('connected_entries').select { |c| c['Type'] == 'EventInfrastructure' }.map { |c| c['Id'] } }, ->(s) { s.dig('connected_entries').present? })
          .>> t(:add_links, 'feratel_guest_cards', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('GuestCards', 'GuestCard'))&.flatten&.reject(&:nil?)&.map { |item| "#{item&.dig('Id')&.downcase} - #{item&.dig('UsageType')}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('feratel_guest_cards') })
          .>> t(:universal_classifications, ->(s) { parse_system_letters(s.dig('Systems')) })
          .>> t(:add_field, 'feratel_guest_cards_descriptions', ->(s) { parse_guest_card_descriptions(Array.wrap(s&.dig('GuestCards', 'GuestCard'))&.flatten&.reject(&:nil?), s&.dig('external_key'), external_source_id) || [] })
          .>> t(:merge_array_values, 'additional_information', 'feratel_guest_cards_descriptions')
          .>> t(:merge_array_values, 'content_location', 'connected_location')
          .>> t(:reject_keys, ['Systems', '_Type', 'ChangeDate', 'Addresses', 'Documents', 'feratel_documents', 'Facilities', 'CustomAttributes', 'Location', 'Towns', 'Position', 'connected_entries', 'connected_location'])
          .>> t(:strip_all)
        end
        # .>> t(:add_field, 'start_date', ->(s) { s.dig('event_schedule')&.map { |schedule| schedule.dig(:dtstart) }&.min })
        # .>> t(:add_field, 'end_date', ->(s) { s.dig('event_schedule')&.map { |schedule| schedule.dig(:dtend) }&.max })
        # .>> t(:nest, 'event_period', ['start_date', 'end_date'])

        def self.feratel_to_serial_event(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Name' => 'name')
          .>> t(:unwrap_description, ['EventHeader'])
          .>> t(:add_field, 'additional_information', ->(s) { parse_descriptions(s.dig('Descriptions', 'Description'), external_source_id, 'serial_event') })
          .>> t(:add_field, 'description', ->(v) { DataCycleCore::Utility::Sanitize::String.format_html(v&.dig('EventHeader')) if v&.dig('EventHeader').present? })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['EventHeader']))
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Active')) })
          .>> t(:reject_keys, ['_Type', 'ChangeDate', 'Documents', 'feratel_documents', 'CustomAttributes'])
          .>> t(:strip_all)
        end

        def self.feratel_to_infrastructure(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:unwrap, 'Details')
          .>> t(:rename_keys, 'Id' => 'external_key', 'Names' => 'name')
          .>> t(:unwrap_description, ['InfrastructureLong', 'InfrastructureShort', 'InfrastructurePriceInfo'])
          .>> t(:add_field, 'description', ->(v) { DataCycleCore::Utility::Sanitize::String.format_html(v&.dig('InfrastructureShort')) if v&.dig('InfrastructureShort').present? })
          .>> t(:add_field, 'text', ->(v) { DataCycleCore::Utility::Sanitize::String.format_html(v&.dig('InfrastructureLong')) if v&.dig('InfrastructureLong').present? })
          .>> t(:add_field, 'price_range', ->(v) { DataCycleCore::Utility::Sanitize::String.format_html(v&.dig('InfrastructurePriceInfo')) if v&.dig('InfrastructurePriceInfo').present? })
          .>> t(:remove_description, ['GuestCardClassification'])
          .>> t(:add_field, 'additional_information', ->(s) { parse_descriptions(s.dig('Descriptions', 'Description'), external_source_id, 'infrastructure') })
          .>> t(:unwrap_address_data, 'InfrastructureExternal', ->(s) { Array.wrap(s.dig('Addresses', 'Address')) })
          .>> t(:unwrap, 'Address', ['AddressLine1', 'Town', 'ZipCode', 'Country', 'Fax', 'Phone', 'Email', 'URL'])
          .>> t(:rename_keys, { 'AddressLine1' => 'street_address', 'Town' => 'address_locality', 'ZipCode' => 'postal_code', 'Country' => 'address_country' })
          .>> t(:rename_keys, { 'Fax' => 'fax_number', 'Phone' => 'telephone', 'Email' => 'email', 'URL' => 'url' })
          .>> t(:map_value, 'url', ->(s) { parse_url(s) })
          .>> t(:nest, 'address', ['street_address', 'address_locality', 'address_country', 'postal_code'])
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'email', 'url'])
          .>> t(:unwrap, 'Position')
          .>> t(:rename_keys, 'Latitude' => 'latitude', 'Longitude' => 'longitude')
          .>> t(:map_value, 'latitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:map_value, 'longitude', ->(v) { v.blank? || v.to_f.zero? ? nil : v.to_f })
          .>> t(:location)
          .>> t(:add_field, 'opening_hours_specification', ->(s) { DataCycleCore::Generic::Common::OpeningHours.parse_opening_times(s.dig('OpeningHours', 'OpeningHour'), external_source_id, s['external_key'], ->(d) { day_transformation(d) }) })
          .>> t(:add_field, 'opening_hours_description', ->(s) { parse_opening_hours_descriptions(s.dig('Descriptions', 'Description'), external_source_id) })
          .>> t(:add_field, 'feratel_documents', ->(s) { Array.wrap(s.dig('Documents', 'Document')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['Infrastructure']))
          .>> t(:add_links, 'logo', DataCycleCore::Thing, external_source_id, document_filter(document_classes: ['Image'], document_types: ['InfrastructureLogo']))
          .>> t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('HolidayThemes', 'Item')]&.flatten&.reject(&:nil?)&.map { |item| item&.dig('Id')&.downcase } || [] })
          .>> t(:add_links, 'feratel_owners', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('DataOwner').present? ? ["OWNER:#{Digest::MD5.new.update(s&.dig('DataOwner')).hexdigest}"] : [] })
          .>> t(:add_links, 'feratel_topics', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Topics', 'Topic')]&.flatten&.map { |item| item&.dig('Id') } || [] })
          .>> t(:add_links, 'feratel_locations', DataCycleCore::Classification, external_source_id, ->(s) { [s&.dig('Towns', 'Item')]&.flatten&.map { |item| item&.dig('Id') } || [] })
          .>> t(:add_links, 'feratel_guest_cards', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('GuestCards', 'GuestCard'))&.flatten&.reject(&:nil?)&.map { |item| "#{item&.dig('Id')&.downcase} - #{item&.dig('UsageType')}" } || [] })
          .>> t(:universal_classifications, ->(s) { s.dig('feratel_guest_cards') })
          .>> t(:universal_classifications, ->(s) { parse_system_letters(s.dig('Systems')) })
          .>> t(:add_field, 'feratel_guest_cards_descriptions', ->(s) { parse_guest_card_descriptions(Array.wrap(s&.dig('GuestCards', 'GuestCard'))&.flatten&.reject(&:nil?), s&.dig('external_key'), external_source_id) || [] })
          .>> t(:merge_array_values, 'additional_information', 'feratel_guest_cards_descriptions')
          .>> t(:universal_classifications, ->(s) { Array.wrap(s.dig('HandicapFacilities', 'HandicapFacility')).map { |facility| DataCycleCore::Classification.find_by(external_key: "Feratel - HandicapFacility - #{facility.dig('Id')}")&.id }.compact })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Active')) })
          .>> t(:add_field, 'content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:add_field, 'feratel_content_score', ->(v) { v&.dig('QualityDetails', 'ContentScore').present? ? v&.dig('QualityDetails', 'ContentScore')&.to_f : 0 })
          .>> t(:load_category, 'feratel_types', external_source_id, ->(v) { 'Feratel - Infrastrukturtyp - ' + v&.dig('Topics', 'Type').to_s })
          .>> t(:reject_keys, ['Links', 'OpeningHours', 'Towns', 'CustomAttributes', 'FoodAndBeverage', 'ConnectedEntries', 'HolidayThemes', 'DataOwner', 'Active', 'Address', 'Topics', 'ChangeDate', 'Systems', '_Type'])
          .>> t(:strip_all)
        end

        def self.day_transformation(days)
          day_keys = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].freeze

          day_keys.map { |d|
            next unless days[d] == 'true'

            day_keys.index(d)
          }.compact
        end

        def self.parse_guest_card_descriptions(data, parent_id, external_source_id)
          return [] if data.blank?

          parsed = []
          data.each do |item|
            description = Array.wrap(item.dig('Descriptions', 'Description')).first

            if description.blank?
              description = {}
              description['Id'] = "#{parent_id} - #{item.dig('Id')} - #{item.dig('ValidFrom')} - #{item.dig('ValidTo')} - #{item.dig('UsageType')} - #{item.dig('ChangeDate')} - #{I18n.locale}"
              description['ChangeDate'] = item.dig('ChangeDate')
              description['Type'] = 'GuestCardClassification'
            end

            description['ShowFrom'] = item.dig('ValidFrom').in_time_zone.beginning_of_day
            description['ShowTo'] = item.dig('ValidTo').in_time_zone.end_of_day

            parsed.push(parse_descriptions(description, external_source_id, 'GuestCards', ["#{item&.dig('Id')&.downcase} - #{item&.dig('UsageType')}"]).first)
          end
          parsed
        end

        def self.feratel_to_room(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:rename_keys, 'Id' => 'external_key')
          .>> t(:add_field, 'name', ->(s) { s.dig('Details', 'Name') })
          .>> t(:add_field, 'number_of_rooms', ->(s) { s.dig('Details', 'Rooms')&.to_i })
          .>> t(:add_field, 'floor_size', ->(s) { s.dig('Details', 'Size')&.to_f })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Details', 'Active')) })
          .>> t(:add_links, 'feratel_product_type', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Type').present? ? ["Feratel - Produktart - #{s&.dig('Details', 'type')}"] : [] })
          .>> t(:unwrap_description, 'ServiceDescription')
          .>> t(:add_field, 'description', ->(s) { DataCycleCore::Utility::Sanitize::String.format_html(s&.dig('ServiceDescription')) })
          .>> t(:strip_all)
        end

        def self.feratel_to_additional_service(external_source_id)
          t(:stringify_keys)
          .>> t(:flatten_translations)
          .>> t(:flatten_texts)
          .>> t(:add_field, 'id', ->(s) { t(:find_thing_ids).call(external_system_id: external_source_id, external_key: s.dig('Id'), limit: 1).first })
          .>> t(:rename_keys, 'Id' => 'external_key')
          .>> t(:add_field, 'name', ->(s) { s.dig('Details', 'Name') })
          .>> t(:add_field, 'feratel_status', ->(s) { load_active(s.dig('Details', 'Active')) })
          .>> t(:add_links, 'feratel_product_type', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('Details', 'Type').present? ? ["Feratel - Produktart - #{s&.dig('Details', 'Type')}"] : [] })
          .>> t(:strip_all)
        end

        def self.parse_products(data, external_source_id)
          return if data.blank?
          all_products = []
          data.each do |item|
            item_offered_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: item.dig('Id'), limit: 1).first
            all_products += parse_product(Array.wrap(item.dig('Products', 'Product')), external_source_id, item_offered_id)
          end
          all_products
        end

        def self.parse_product(data, external_source_id, item_offered_id)
          return [] if data.blank?
          data.map { |item|
            thing_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: item.dig('Id'), limit: 1).first
            data_hash = {}
            data_hash['id'] = thing_id if thing_id.present?
            type_classification = DataCycleCore::ClassificationAlias
              .for_tree('Feratel - Produktarten')
              .find_by(internal_name: item.dig('Details', 'ProductType'))
              &.classifications
              &.pluck(:id)
            accommodation_classification = DataCycleCore::ClassificationAlias
              .for_tree('Feratel - Unterkunftstypen')
              .find_by(internal_name: item.dig('Details', 'AccommodationType'))
              &.classifications
              &.pluck(:id)
            data_hash.merge({
              name: item.dig('Details', 'Name'),
              description: DataCycleCore::Utility::Sanitize::String.format_html(t(:unwrap_description, 'ProductDescription').call(item).dig('ProductDescription')),
              item_offered: [item_offered_id],
              external_key: item.dig('Id'),
              price_specification: parse_simple_price(item.dig('Price'), external_source_id, item.dig('Id')),
              feratel_product_type: Array(type_classification),
              feratel_accommodation_type: Array(accommodation_classification),
              feratel_status: load_active(item.dig('Details', 'Active')),
              offer_period: parse_period(item.dig('Details', 'ValidDates'))
            })
          }.compact
        end

        def self.parse_simple_price(data, external_source_id, key)
          return if data.blank?
          data_hash = {}
          data_hash['external_key'] = [key, '/price_specification'].join(' ')
          thing_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: data_hash['external_key'], limit: 1).first
          data_hash['id'] = thing_id if thing_id.present?
          meal_code = DataCycleCore::ClassificationAlias
            .for_tree('Feratel - Verpflegungs Kürzel')
            .find_by(internal_name: data.dig('StandardMealCode'))
            &.classifications
            &.pluck(:id)
          data_hash['feratel_meal_code'] = meal_code if meal_code.present?
          data_hash['unit_text'] = "#{data.dig('Nights')} night(s) / #{data.dig('Rule')}"
          prices = Array.wrap(data.dig('Range')).map { |item| [item.dig('From')&.to_f, item.dig('To')&.to_f].compact.reject(&:zero?) }.flatten
          data_hash['min_price'] = prices.min
          data_hash['max_price'] = prices.max
          [data_hash]
        end

        def self.parse_period(data)
          return unless data&.dig('Type') == 'Period'
          dates = Array.wrap(data.dig('ValidDate'))
            .map { |item| [item['From'].try(:to_date), item['To'].try(:to_date)].compact }.flatten
          {
            'valid_from' => dates.min,
            'valid_through' => dates.max
          }
        end

        def self.parse_packages(data, external_source_id)
          return if data.blank?
          data.map { |item|
            thing_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: item.dig('Id'), limit: 1).first
            data_hash = {}
            data_hash['id'] = thing_id if thing_id.present?
            data_hash.merge({
              name: item.dig('Details', 'Name'),
              description: DataCycleCore::Utility::Sanitize::String.format_html(t(:unwrap_description, 'Package').call(item).dig('Package')),
              text: DataCycleCore::Utility::Sanitize::String.format_html(t(:unwrap_description, 'PackageContentLong').call(item).dig('PackageContentLong')),
              feratel_status: load_active(item.dig('Details', 'Active')),
              offer_period: parse_period(item.dig('Details', 'ValidDates')),
              holiday_themes: t(:add_links, 'holiday_themes', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s&.dig('HolidayThemes', 'Item'))&.reject(&:nil?)&.map { |entry| entry&.dig('Id')&.downcase } || [] }).call(item).dig('holiday_themes'),
              external_key: item.dig('Id')
            })
          }.compact
        end

        def self.parse_package_offers(data_array, external_source_id)
          data_array.map { |data|
            data_hash = {}
            package_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: data.dig('Id'), limit: 1).first
            data_hash['id'] = package_id if package_id.present?
            meal_code = DataCycleCore::ClassificationAlias
              .for_tree('Feratel - Verpflegungs Kürzel')
              .find_by(internal_name: data.dig('MealCode'))
              &.classifications
              &.pluck(:id)
            price_hash = {}
            price_id = t(:find_thing_ids).call(external_system_id: external_source_id, external_key: "#{data.dig('Id')}/price_specification", limit: 1).first
            price_hash['id'] = price_id if price_id.present?
            price_hash['min_price'] = data&.dig('PriceFrom')&.to_f
            price_hash['feratel_meal_code'] = meal_code
            data_hash.merge({
              'external_key' => data.dig('Id'),
              'name' => data&.dig('Name'),
              'price_specification' => Array.wrap(price_hash)
            })
          }.compact
        end

        def self.min_price(data)
          return if data.blank?
          data
            .map { |item| item.dig('PriceFrom') }
            &.compact
            &.map(&:to_f)
            &.reject { |item| item == 0.0 }
            &.min
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
          DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Wochentage', day_hash[day])
        end

        def self.load_active(value)
          return unless ['true', 'false'].include?(value)
          classification = 'Aktiv' if value == 'true'
          classification = 'Inaktiv' if value == 'false'
          DataCycleCore::ClassificationAlias
            .for_tree('Feratel - Status')
            .find_by(internal_name: classification)
            .classifications
            .pluck(:id)
        end

        def self.load_offer_status(value)
          return unless ['true', 'false'].include?(value)
          classification = 'Buchbar' if value == 'true'
          classification = 'Nicht Buchbar' if value == 'false'
          DataCycleCore::ClassificationAlias
            .for_tree('Feratel - Angebot - Status')
            .find_by(internal_name: classification)
            .classifications
            .pluck(:id)
        end

        def self.load_price_type(value)
          return if value.blank?
          case value
          when 'perPerson'
            classification = 'Preis pro Person'
          when 'perPackage'
            classification = 'Preis pro Package'
          else
            raise "Unknown price type '#{value}'"
          end
          DataCycleCore::ClassificationAlias
            .for_tree('Feratel - Preis - Typ')
            .find_by(internal_name: classification)
            .classifications
            .pluck(:id)
        end

        def self.document_filter(document_classes: [], document_types: [])
          lambda do |data|
            data&.dig('feratel_documents')
              &.select { |d| document_classes.include?(d['Class']) && document_types.include?(d['Type']) }
              &.sort_by { |item| item['Order'].to_i }
              &.map { |item| item&.dig('Id') } || []
          end
        end

        def self.load_feratel_event_tags(names)
          names.compact.map do |name|
            DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Feratel - Veranstaltungstags', name)
          end
        end

        def self.load_event_schedules(data, external_source_id)
          available_dates = Array.wrap(data.dig('Dates', 'Date')).uniq
          available_start_times = Array.wrap(data.dig('StartTimes', 'StartTime')).uniq
          duration = event_duration(data.dig('Duration', 'Type'), data.dig('Duration', 'text'))

          res = []
          return nil if available_dates.blank?

          available_dates.each do |date|
            start_date = date['From']
            end_date = date['To']
            if available_start_times.present?
              available_start_times.each do |time_items|
                start_time = time_items['Time'].to_datetime
                active_days = time_items.except('Time').select { |_day, val| val == 'true' }.map { |key, _val|
                  load_day_of_week_id(key)
                }&.reject(&:blank?)
                end_time = duration ? (start_time + duration.minutes).strftime('%H:%M') : nil

                time_res = {
                  event_date: {
                    start_date: start_date,
                    end_date: end_date
                  },
                  event_time: {
                    start_time: start_time&.strftime('%H:%M'),
                    end_time: end_time
                  },
                  day_of_week: active_days
                }

                res << time_res
              end
            else
              res << {
                event_date: {
                  start_date: start_date,
                  end_date: end_date
                }
              }
            end
          end
          res
            .flatten
            .sort_by { |o| o[:event_date][:start_date] }
            .map do |item|
              schedule_key = Digest::SHA1.hexdigest "#{data.dig('external_key')}-#{item.to_json}"
              item.merge({
                id: DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: schedule_key)&.id,
                external_source_id: external_source_id,
                external_key: schedule_key
              })
            end
        end

        def self.event_duration(type, value)
          case type
          when nil
            nil
          when 'None'
            nil
          when 'Day'
            nil
          # value.to_f * 24 * 60
          when 'Hour'
            value.to_f * 60
          when 'Minute'
            value.to_f
          else
            raise "Unknown duration type '#{type}'"
          end
        end

        def self.load_schedules(data, external_source_id)
          available_dates = Array.wrap(data.dig('Dates', 'Date')).uniq
          available_start_times = Array.wrap(data.dig('StartTimes', 'StartTime')).uniq
          duration = duration(data.dig('Duration', 'Type'), data.dig('Duration', 'text')) || duration(data.dig('Durations', 'Type'), data.dig('Durations', 'Duration')) || 0
          options = {}
          options = { duration: duration } if duration.positive?

          res = []
          return nil if available_dates.blank?

          available_dates.each do |date|
            dstart = date['From'].presence
            dend = date['To'].presence
            options = {} if duration > 1.day && dend.present? # duration is interpreted for the entierty of all event not only a single event

            if available_start_times.present?
              available_start_times.each do |time_item|
                tstart = time_item['Time'].presence
                dtstart = "#{dstart}T#{tstart}".in_time_zone
                dtend = nil
                if dend.present?
                  dtend = "#{dend}T#{tstart}".in_time_zone
                  untild = dtend
                  if duration == 1.day && dstart == dend
                    dtend = dtend.end_of_day
                  elsif duration < 1.day
                    dtend += duration
                  end
                elsif duration.present?
                  dtend = dtstart + duration
                  untild = dtstart
                else
                  dtend = dtstart
                  untild = dtstart
                end
                untildt = DataCycleCore::Schedule.until_as_utc_iso8601(untild, dtstart).to_datetime.utc

                active_days = time_item
                  .except('Time')
                  .select { |_day, val| val == 'true' }
                  .map { |day, _val| load_day_nr(day) }
                  .compact
                  .presence

                rrule = active_days&.size.to_i.in?(1..6) ? IceCube::Rule.weekly : IceCube::Rule.daily

                time = tstart.to_datetime
                rrule.hour_of_day(time.hour)
                rrule.minute_of_hour(time.minute) if time.minute.positive?
                rrule.day(active_days) if active_days.present?
                rrule.until(untildt)
                schedule_object = IceCube::Schedule.new(dtstart, options) do |s|
                  s.add_recurrence_rule(rrule)
                end
                res << schedule_object.to_hash.merge(dtstart: dtstart, dtend: dtend).compact if schedule_object.all_occurrences.size.positive?
              end
            else
              dstart = nil
              dend = nil
              dstart = Time.zone.parse(date['From']) if date['From'].present?
              dend = Time.zone.parse(date['To'])&.end_of_day if date['To'].present?

              res << {
                start_time: { time: dstart, zone: dstart.time_zone.name },
                end_time: { time: dend, zone: dend.time_zone.name },
                duration: dend.to_i - dstart.to_i
              }
            end
          end
          res
            .sort_by { |item| item[:dtstart] }
            .map do |item|
              schedule_key = Digest::SHA1.hexdigest "#{data.dig('external_key')}-#{item.to_json}"
              item.merge({
                id: DataCycleCore::Schedule.find_by(external_source_id: external_source_id, external_key: schedule_key)&.id,
                external_source_id: external_source_id,
                external_key: schedule_key
              })
            end
        end

        def self.load_day_nr(day)
          return nil unless ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].include?(day)
          { 'Mon' => 1, 'Tue' => 2, 'Wed' => 3, 'Thu' => 4, 'Fri' => 5, 'Sat' => 6, 'Sun' => 0 }[day]
        end

        def self.duration(type, value)
          return nil if value.is_a?(::Array)
          case type
          when nil
            nil
          when 'None'
            nil
          when 'Day'
            value.to_f * 24 * 60 * 60
          when 'Hour'
            value.to_f * 60 * 60
          when 'Minute'
            value.to_f * 60
          else
            raise "Unknown duration type '#{type}'"
          end
        end

        def self.systems_hash
          @systems_hash ||= ['L', 'T', 'I', 'C', 'P'].map { |i|
            { i => DataCycleCore::ClassificationAlias.for_tree('Feratel - Systeme').find_by(description: i)&.primary_classification&.id }
          }.inject(&:merge)
        end

        def self.parse_system_letters(string)
          return [] if string.blank? || string.strip.blank?
          systems = []
          string.strip.delete(' ').each_char { |i| systems.push(systems_hash[i]) if systems_hash[i].present? }
          systems
        end
      end
    end
  end
end
