
module DataCycleCore
  module Generic
    module Xamoom
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil)
          @host = host
          @end_point = end_point
          @key = key
          @per = 100
        end

        def spots(lang: :de)
          first_page = load_data(0, lang)
          total_items = first_page['meta']['total'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              page = load_data(page - 1, lang)['data'].each do |image_record|
                yielder << image_record
              end
            end
          end
        end

        protected

        def load_data(page = 0, lang = :de)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point])

            req.headers['Accept'] = 'application/json'
            req.headers['Apikey'] = @key
            req.params['lang'] = lang.to_s
            req.params['page[size]'] = @per
            req.params['page[cursor]'] = page
          end

          if response.success?
            JSON.parse(response.body)
          else
            raise DataCycleCore::Generic::RecoverableError, "error loading data from #{File.join([@host, @end_point, @project] + url_path)}"
          end
        end
      end
    end
  end
end