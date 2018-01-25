module DataCycleCore
  class RestClient
    def initialize(base_url, credentials, verbose = false)
      @credentials = credentials

      if setup_credentials(credentials)
        @conn = Faraday.new(url: base_url) do |faraday|
          faraday.response :logger if verbose       # write requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      else
        raise TypeError, "from DataCycleCore::RestClient --> no valid credentials given: received credentails: #{credentials.inspect}"
      end
    end

    def setup_credentials(credentials)
      # dummy implementation, if no credentials are required
      true
    end
  end
end
