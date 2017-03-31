module DataCycleCore
  module Jsonld

    class RestClient

      def initialize(base_url, verbose=false)
        @conn=Faraday.new(:url => base_url) do |faraday|
          faraday.response :logger if verbose       # write requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
        return self
      end

      def get(end_point, page = 0, per = 30)
        @conn.get do |req|
          req.url end_point
          req.headers['Accept'] = 'application/json'
          req.params['page'] = page
          req.params['per'] = per
        end
      end
    end

  end
end
