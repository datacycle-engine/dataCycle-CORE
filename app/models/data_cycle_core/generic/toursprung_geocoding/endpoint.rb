# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ToursprungGeocoding
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil, allow_ambiguous_address: nil, **options)
          @host = host
          @end_point = end_point
          @key = key
          @options = options
          @allow_ambiguous_address = allow_ambiguous_address
        end

        def geocode(address, locale = I18n.locale)
          unless address.present? && (address.is_a?(::Hash) || address.is_a?(DataCycleCore::OpenStructHash))
            return OpenStruct.new(error: {
              path: 'validation.warnings.no_data',
              substitutions: {
                data: 'Adresse'
              }
            })
          end

          address_string = [address.dig('street_address'), address.dig('postal_code'), address.dig('address_locality'), address.dig('address_country')].join(',')
          data = load_data(address: address_string, locale: locale)
          if data.blank?
            return OpenStruct.new(error: {
              path: 'validation.warnings.address_not_found'
            })
          end

          if data.many? && !@allow_ambiguous_address
            return OpenStruct.new(error: {
              path: 'validation.warnings.address_ambiguous'
            })
          end

          geodata = parse_geo(data.first)

          if geodata.try(:x).blank? || geodata.try(:y).blank?
            return OpenStruct.new(error: {
              path: 'validation.warnings.address_not_found'
            })
          end

          geodata
        end

        # def reverse_geocode(geo, locale = :de)
        #   return if geo.blank?
        #   return unless geo.respond_to?(:x)
        #   return unless geo.respond_to?(:y)

        #   geo_string = [geo.y, geo.x].join(',')
        #   data = load_data(latlng: geo_string, locale: locale)['results']
        #   return if data.blank?

        #   parse_address(data&.first)
        # end

        def parse_geo(raw_data)
          return if raw_data.blank?
          factory = RGeo::Geographic.simple_mercator_factory
          factory.point(raw_data.dig('lon')&.to_f&.round(5), raw_data.dig('lat')&.to_f&.round(5))
        end

        def load_data(latlng: nil, address: nil, locale: :de)
          response = Faraday.new.get do |req|
            req.url(URI.join(@host, @end_point))
            req.headers['Accept'] = 'application/json'
            req.params['q'] = address if address.present?
            req.params['language'] = locale.to_s
            req.params['limit'] = 2
            req.params['apiKey'] = @key
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + 'geocode/json'} / latlng:#{latlng} / address:#{address}", response) unless response.success?
          data = JSON.parse(response.body)

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point + 'geocode/json'} / latlng:#{latlng} / address:#{address}", response) unless data.try(:length)
          data
        end
      end
    end
  end
end
