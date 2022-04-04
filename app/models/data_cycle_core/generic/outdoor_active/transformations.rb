# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.outdoor_active_to_place(external_source_id)
          t(:stringify_keys)
          .>> t(
            :rename_keys,
            {
              'id' => 'external_key',
              'title' => 'name',
              'altitude' => 'elevation',
              'fax' => 'fax_number',
              'phone' => 'telephone',
              'homepage' => 'url'
            }
          )
          .>> t(:add_field, 'description', ->(s) { s.dig('shortText') })
          .>> t(:add_field, 'text', ->(s) { s.dig('longText') })
          .>> t(:add_field, 'directions', ->(s) { s.dig('gettingThere') })
          .>> t(:add_field, 'hours_available', ->(s) { s.dig('businessHours') })
          .>> t(:add_field, 'price', ->(s) { s.dig('fee') })
          .>> t(:add_field, 'content_score', ->(s) { s.dig('ranking')&.to_f || 0 })
          .>> t(:add_field, 'additional_information', ->(s) { to_additional_information(s, 'place', external_source_id) })
          .>> t(:map_value, 'elevation', ->(s) { s.try(:to_f) })
          .>> t(:add_field, 'latitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 1).try(:to_f) })
          .>> t(:add_field, 'longitude', ->(s) { s['geometry'].try(:split, /[, ]/, 3).try(:[], 0).try(:to_f) })
          .>> t(:location)
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('address', 'town') })
          .>> t(:add_field, 'street_address', ->(s) { [s.dig('address', 'street')&.strip, s.dig('address', 'housenumber')&.strip].join(' ') if s.dig('address', 'street')&.strip.present? })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('address', 'zipcode') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('address', 'countryname') })
          .>> t(:reject_keys, ['address'])
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_country', 'address_locality'])
          .>> t(:nest, 'contact_info', ['telephone', 'fax_number', 'url', 'email'])
          .>> t(:add_field, 'author', ->(s) { s.dig('meta', 'author') })
          .>> t(:universal_classifications, ->(s) { load_opened(s.dig('opened')) })
          .>> t(:universal_classifications, ->(s) { load_winter_activity(s.dig('winterActivity')) })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('images', 'image')&.map { |item| item&.dig('id') } || [] })
          .>> t(:add_links, 'primary_image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('primaryImage')&.dig('id') })
          .>> t(:add_links, 'regions', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('regions', 'region')&.map { |item| "REGION:#{item&.dig('id')}" } || [] })
          .>> t(:add_links, 'source', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('meta', 'source', 'id').present? ? ["SOURCE:#{s&.dig('meta', 'source', 'id')}"] : [] })
          .>> t(:load_category, 'poi_categories', external_source_id, ->(s) { s&.dig('category', 'id').present? ? "CATEGORY:#{s&.dig('category', 'id')}" : nil })
          .>> t(:load_category, 'frontend_type', external_source_id, ->(s) { s&.dig('frontendtype').present? ? "FRONTENDTYPE:#{Digest::MD5.new.update(s.dig('frontendtype')).hexdigest}" : nil })
          .>> t(:category_key_to_ids, 'outdoor_active_tags', ->(s) { s&.dig('properties', 'property') }, nil, external_source_id, 'TAG:', 'tag')
          .>> t(:reject_keys, ['category', 'primaryImage', 'images', 'regions', 'meta'])
          .>> t(:strip_all)
        end

        def self.outdoor_active_to_tour(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'content_score', ->(s) { s.dig('ranking')&.to_f || 0 })
          .>> t(:add_field, 'latitude', ->(s) { s.dig('startingPoint', 'lon')&.to_f })
          .>> t(:add_field, 'longitude', ->(s) { s.dig('startingPoint', 'lat')&.to_f })
          .>> t(:add_field, 'start_location', ->(s) { RGeo::Geographic.spherical_factory(srid: 4326).point(s['latitude'], s['longitude']) if s['longitude'] && s['latitude'] })
          .>> t(:add_field, 'line', ->(s) { tour(s&.dig('geometry')) })
          .>> t(:unwrap, 'elevation', ['ascent', 'descent', 'minAltitude', 'maxAltitude'])
          .>> t(:unwrap, 'time', ['min'])
          .>> t(:unwrap, 'rating', ['condition', 'difficulty', 'qualityOfExperience', 'landscape', 'technique'])
          .>> t(:reject_keys, ['rating'])
          .>> t(:add_field, 'author', ->(s) { s.dig('meta', 'author') })
          .>> t(
            :rename_keys,
            {
              'id' => 'external_key',
              'title' => 'name',
              'altitude' => 'elevation',
              'minAltitude' => 'min_altitude',
              'maxAltitude' => 'max_altitude',
              'min' => 'duration',
              'condition' => 'condition_rating',
              'difficulty' => 'difficulty_rating',
              'qualityOfExperience' => 'experience_rating',
              'landscape' => 'landscape_rating',
              'technique' => 'technique_rating'
            }
          )
          .>> t(:add_field, 'description', ->(s) { s.dig('shortText') })
          .>> t(:add_field, 'text', ->(s) { s.dig('longText') })
          .>> t(:add_field, 'instructions', ->(s) { s.dig('directions') })
          .>> t(:add_field, 'directions', ->(s) { s.dig('gettingThere') })
          .>> t(:add_field, 'directions_public_transport', ->(s) { s.dig('publicTransit') })
          .>> t(:add_field, 'safety_instructions', ->(s) { s.dig('safetyGuidelines') })
          .>> t(:add_field, 'suggestion', ->(s) { s.dig('tip') })
          .>> t(:add_field, 'additional_information', ->(s) { s.dig('additionalInformation') })
          .>> t(:add_field, 'additional_information', ->(s) { to_additional_information(s, 'tour', external_source_id) })
          .>> t(:add_field, 'schedule', ->(s) { load_tour_season(s.dig('season')) })
          .>> t(:map_value, 'elevation', ->(s) { s&.to_f })
          .>> t(:map_value, 'length', ->(s) { s&.to_f })
          .>> t(:map_value, 'duration', ->(s) { s&.to_i })
          .>> t(:map_value, 'condition_rating', ->(s) { s&.to_i })
          .>> t(:map_value, 'difficulty_rating', ->(s) { s&.to_i })
          .>> t(:map_value, 'experience_rating', ->(s) { s&.to_i })
          .>> t(:map_value, 'landscape_rating', ->(s) { s&.to_i })
          .>> t(:map_value, 'technique_rating', ->(s) { s&.to_i })
          .>> t(:universal_classifications, ->(s) { Array.wrap(load_difficulty_rating(s.dig('difficulty_rating'))) })
          .>> t(:universal_classifications, ->(s) { load_opened(s.dig('opened')) })
          .>> t(:universal_classifications, ->(s) { load_winter_activity(s.dig('winterActivity')) })
          .>> t(:add_links, 'poi', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('pois', 'poi')&.map { |item| item&.dig('id') } || [] })
          .>> t(:add_links, 'contains_place', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('stageTours')&.map { |item| item&.dig('id') } || [] })
          .>> t(:add_links, 'contained_in_place', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s.dig('stageTour')).compact })
          .>> t(:add_links, 'primary_image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('primaryImage', 'id') })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { s&.dig('images', 'image')&.map { |item| item&.dig('id') } || [] })
          .>> t(:load_category, 'tour_categories', external_source_id, ->(s) { s&.dig('category', 'id').present? ? "CATEGORY:#{s&.dig('category', 'id')}" : nil })
          .>> t(:load_category, 'frontend_type', external_source_id, ->(s) { s&.dig('frontendtype').present? ? "FRONTENDTYPE:#{Digest::MD5.new.update(s.dig('frontendtype')).hexdigest}" : nil })
          .>> t(:category_key_to_ids, 'outdoor_active_tags', ->(s) { s&.dig('properties', 'property') }, nil, external_source_id, 'TAG:', 'tag')
          .>> t(:add_links, 'regions', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('regions', 'region')&.map { |item| "REGION:#{item&.dig('id')}" } || [] })
          .>> t(:add_links, 'source', DataCycleCore::Classification, external_source_id, ->(s) { s&.dig('meta', 'source', 'id').present? ? ["SOURCE:#{s&.dig('meta', 'source', 'id')}"] : nil })
          .>> t(:strip_all)
        end

        def self.load_opened(opened)
          return [] unless opened.in?([true, false])
          status = opened ? 'geöffnet' : 'geschlossen'
          DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('OutdoorActive - Status', status)
        end

        def self.load_winter_activity(winter)
          return [] unless winter == true
          DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('OutdoorActive - Status', 'Winteraktivität')
        end

        def self.load_difficulty_rating(rating)
          rating_name =
            case rating
            when 1
              'leicht'
            when 2
              'mittel'
            when 3
              'schwierig'
            else
              'unbekannt'
            end
          DataCycleCore::ClassificationAlias.classification_for_tree_with_name('OutdoorActive - Schwierigkeitsgrad', rating_name)
        end

        def self.outdoor_active_to_image(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'content_url', ->(s) { "http://img.oastatic.com/img/#{s['id']}/.jpg" })
          .>> t(:add_field, 'thumbnail_url', ->(s) { "http://img.oastatic.com/img/400/400/fit/#{s['id']}/.jpg" })
          .>> t(:add_links, 'copyright_holder', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Generic::OutdoorActive::Processing.get_copyright_holder(s)['external_key'] }, ->(s) { DataCycleCore::Generic::OutdoorActive::Processing.get_copyright_holder(s)['external_key'] })
          .>> t(:universal_classifications, ->(s) { s.dig('license', 'short').blank? ? [] : DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('OutdoorActive - Lizenzen', s.dig('license', 'short')) })
          .>> t(:add_field, 'caption', ->(s) { [s.dig('author'), s.dig('source').is_a?(::Hash) ? s.dig('source', 'name') : s.dig('source')]&.reject(&:blank?)&.join(' - ') })
          .>> t(:map_value, 'license', ->(v) { v.dig('url') if v.present? })
          .>> t(:rename_keys, { 'id' => 'external_key', 'title' => 'name' })
          .>> t(:map_value, 'name', ->(v) { v || '__NO_NAME__' })
          .>> t(:add_links, 'author', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Generic::OutdoorActive::Processing.get_author_data(s)['external_key'] }, ->(s) { DataCycleCore::Generic::OutdoorActive::Processing.get_author_data(s)['external_key'] })
          .>> t(:reject_keys, ['meta', 'primary', 'gallery'])
          .>> t(:strip_all)
        end

        def self.to_copyright_holder
          t(:stringify_keys)
          .>> t(:add_field, 'contact_info', ->(s) { { 'url' => s.dig('url') } })
          .>> t(:strip_all)
        end

        def self.to_author
          t(:stringify_keys)
          .>> t(:strip_all)
        end

        def self.to_additional_information(hash, type, external_source_id)
          ['description', 'text', 'directions', 'directions_public_transport', 'parking',
           'hours_available', 'price', 'instructions', 'safety_instructions',
           'equipment', 'suggestion', 'additional_information', 'maps'].map { |desc|
            next if hash[desc].blank?
            name = I18n.t("import.outdoor_active.#{type}.#{desc}", default: [desc])
            external_key = "#{desc}:#{I18n.locale}:#{hash.dig('external_key')}"
            id = DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id
            ai_hash = id.blank? ? {} : { 'id' => id }
            ai_hash.merge({
              'name' => name,
              'description' => hash[desc],
              'universal_classifications' => Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Externe Informationstypen', desc)),
              'external_key' => external_key
            })
          }.compact
        end

        def self.tour(geometry)
          return nil if geometry.blank?
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          factory.multi_line_string(
            Array.wrap(
              factory.line_string(
                geometry&.split(' ')
                  &.map { |p| p.split(',').map(&:to_f) }
                  &.map { |p| factory.point(*p) }
              )
            )
          )
        end

        def self.load_tour_season(season)
          return if season.blank?
          season_data = season.select { |_k, val| val.present? }.keys.map { |month| by_month_id(month) }
          return if season_data.blank?
          [
            {
              by_month: season_data
            }
          ]
        end

        def self.by_month_id(month)
          return nil unless ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'].include?(month)
          month_hash = {
            'jan' => 'Januar',
            'feb' => 'Februar',
            'mar' => 'März',
            'apr' => 'April',
            'may' => 'Mai',
            'jun' => 'Juni',
            'jul' => 'Juli',
            'aug' => 'August',
            'sep' => 'September',
            'oct' => 'Oktober',
            'nov' => 'November',
            'dec' => 'Dezember'
          }
          DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Monate', month_hash[month])
        end
      end
    end
  end
end
