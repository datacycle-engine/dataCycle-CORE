# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      class Endpoint
        def initialize(host: nil, end_point: nil, token: nil, **options)
          @host = host
          @end_point = options&.dig(:options, :end_point) || end_point
          @token = token
          @per = 100
        end

        def tags(*)
          first_page = load_data(page: 1)
          total_items = first_page['count'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_data(page: page, per: @per)['Tags'].each do |tag|
                yielder << tag
              end
            end
          end
        end

        def images(_lang: :de)
          first_page = load_data(page: 1)
          total_items = first_page['count'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_data(page: page, per: @per)['CreativeWorks'].each do |image_record|
                yielder << image_record
              end
            end
          end
        end

        def videos(_lang: :de)
          first_page = load_data(page: 1, type: 'video')
          total_items = first_page['count'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_data(page: page, per: @per, type: 'video')['CreativeWorks'].each do |video_record|
                yielder << video_record
              end
            end
          end
        end

        protected

        def load_data(page: 1, per: 1, type: 'image')
          response = Faraday.new.get do |req|
            req.url(@host + @end_point)

            req.headers['Accept'] = 'application/json'

            req.params['page'] = page
            req.params['per'] = per
            req.params['token'] = @token
            req.params['type'] = type
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / page:#{page} / per:#{per} / type:#{type}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
