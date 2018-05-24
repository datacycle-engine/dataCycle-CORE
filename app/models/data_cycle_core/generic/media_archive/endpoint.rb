module DataCycleCore
  module Generic
    module MediaArchive
      class Endpoint
        def initialize(host: nil, end_point: nil, token: nil)
          @host = host
          @end_point = end_point
          @token = token
          @per = 100
        end

        def images(lang: :de)
          first_page = load_data(page: 1)
          total_items = first_page['count'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_data(page: page, per: @per, lang: lang)['CreativeWorks'].each do |image_record|
                yielder << image_record[lang.to_s]
              end
            end
          end
        end

        def videos(lang: :de)
          first_page = load_data(page: 1, type: 'video')
          total_items = first_page['count'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_data(page: page, per: @per, lang: lang, type: 'video')['CreativeWorks'].each do |video_record|
                yielder << video_record[lang.to_s]
              end
            end
          end
        end

        protected

        def load_data(page: 1, per: 1, lang: :de, type: 'image')
          response = Faraday.new.get do |req|
            req.url(@host + @end_point)

            req.headers['Accept'] = 'application/json'

            req.params['page'] = page
            req.params['per'] = per
            req.params['token'] = @token
            req.params['type'] = type
          end

          raise DataCycleCore::Generic::RecoverableError, "error loading data from #{@host + @end_point} / page:#{page} / per:#{per} / lang:#{lang} / type:#{type}" << response.body unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
