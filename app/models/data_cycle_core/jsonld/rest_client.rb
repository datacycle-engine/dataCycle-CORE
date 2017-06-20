module DataCycleCore
  module Jsonld

    class RestClient < DataCycleCore::RestClient

      def get(end_point, page = 0, per = 30)
        @conn.get do |req|
          req.url end_point
          req.headers['Accept'] = 'application/json'
          req.params['page'] = page
          req.params['per'] = per
          req.params['token'] = @credentials['token'] if @credentials && @credentials['token']
        end
      end

    end

  end
end
