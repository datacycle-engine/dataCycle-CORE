# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      class Endpoint
        def initialize(host: nil, end_point: nil, apikey: nil, **_options)
          @host = host
          @end_point = end_point
          @apikey = apikey
        end

        def infrastructures(lang: :de)
          first_page = load_data(1, lang)
          max_pages = first_page['totalPages'].to_i
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_data(page - 1, lang)['items'].each do |infrastructure_record|
                yielder << infrastructure_record
              end
            end
          end
        end

        protected

        def load_data(page = 1, lang = :de)
          sleep 30
          response = Faraday.new.get do |req|
            req.url File.join([@host, lang, @end_point])
            req.params['apikey'] = @apikey
            req.params['page'] = page
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
