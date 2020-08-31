# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GoogleGeocoding
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil, allow_ambiguous_address: nil, **options)
          @host = host
          @end_point = end_point
          @key = key
          @options = options
          @allow_ambiguous_address = allow_ambiguous_address
        end

        def geocode(address, locale = I18n.locale)
          return if address.blank?
          return unless address.is_a?(::Hash) || address.is_a?(DataCycleCore::OpenStructHash)

          address_string = [address.dig('street_address'), [address.dig('postal_code'), address.dig('address_locality')].join(' '), address.dig('address_country')].join(', ')
          data = load_data(address: address_string, locale: locale)['results']
          return if data.blank?

          parse_geo(data.first)
        end

        def reverse_geocode(geo, locale = :de)
          return if geo.blank?
          return unless geo.respond_to?(:x)
          return unless geo.respond_to?(:y)

          geo_string = [geo.y, geo.x].join(',')
          data = load_data(latlng: geo_string, locale: locale)['results']
          return if data.blank?

          parse_address(data&.first)
        end

        def parse_geo(raw_data)
          return if raw_data.blank?
          factory = RGeo::Geographic.simple_mercator_factory
          factory.point(raw_data.dig('geometry', 'location', 'lng')&.to_f&.round(5), raw_data.dig('geometry', 'location', 'lat')&.to_f&.round(5))
        end

        def parse_address(raw_data)
          return if raw_data.blank?
          address = DataCycleCore::OpenStructHash.new
          road = raw_data.dig('address_components')&.select { |item| item['types'].include?('route') }&.first&.dig('long_name')
          street_number = raw_data.dig('address_components')&.select { |item| item['types'].include?('street_number') }&.first&.dig('long_name')
          address['street_address'] = [road, street_number].join(' ')
          address['postal_code'] = raw_data.dig('address_components')&.select { |item| item['types'].include?('postal_code') }&.first&.dig('long_name')
          address['address_locality'] = raw_data.dig('address_components')&.select { |item| item['types'].include?('locality') }&.first&.dig('long_name')
          address['address_country'] = raw_data.dig('address_components')&.select { |item| item['types'].include?('country') }&.first&.dig('long_name')
          address
        end

        def load_data(latlng: nil, address: nil, locale: :de)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'geocode/json')
            req.headers['Accept'] = 'application/json'
            req.params['latlng'] = latlng if latlng.present?
            req.params['address'] = address if address.present?
            req.params['language'] = locale.to_s
            req.params['key'] = @key
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + 'geocode/json'} / latlng:#{latlng} / address:#{address}", response) unless response.success?
          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point + 'geocode/json'} / latlng:#{latlng} / address:#{address}", response) unless data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS'
          data
        end
      end
    end
  end
end
