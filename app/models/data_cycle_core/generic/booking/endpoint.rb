# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Booking
      class Endpoint
        def initialize(host: nil, region_id:, user:, password:, **options)
          @page_size = 300
          @host = host
          @region_id = region_id
          @options = options
          @user = user
          @password = password
        end

        def regions(lang: :de)
          end_point = '/regions'
          Enumerator.new do |yielder|
            load_data(end_point, lang, nil, nil, nil, 'at').each do |region|
              yielder << region
            end
          end
        end

        def hotel_types(lang: :de)
          end_point = '/hotelTypes'
          Enumerator.new do |yielder|
            load_data(end_point, lang).each do |hotel_type|
              yielder << hotel_type
            end
          end
        end

        def hotels(lang: :de)
          end_point = '/hotels'
          offset = 0
          Enumerator.new do |yielder|
            loop do
              data = load_data(end_point, lang, @region_id, ['hotel_info', 'hotel_facilities', 'hotel_description'], offset)
              data.each do |hotel|
                yielder << hotel
              end

              offset += @page_size
              break if data.size < @page_size
            end
          end
        end

        protected

        def load_data(end_point, lang, region_id = nil, extras = nil, offset = nil, countries = nil)
          conn = Faraday.new(url: @host + end_point)
          conn.basic_auth(@user, @password)
          response = conn.get do |req|
            req.params['region_ids'] = region_id if region_id.present?
            req.params['language'] = lang if region_id.present?
            req.params['languages'] = lang if region_id.blank? || countries
            req.params['countries'] = countries if countries.present?
            req.params['extras'] = extras.join(',') if extras.present?
            if offset.present?
              req.params['offset'] = offset
              req.params['rows'] = @page_size
            end
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + end_point} / region_ids:#{@region_id} / extras: #{extras&.join(',')}", response) unless response.success?
          JSON.parse(response.body)['result']
        end
      end
    end
  end
end
