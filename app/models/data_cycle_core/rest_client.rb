module DataCycleCore
  class RestClient
    def initialize(base_url, credentials, verbose = false)
      @credentials = credentials
      raise TypeError, "from DataCycleCore::RestClient --> no valid credentials given: received credentails: #{credentials.inspect}" unless setup_credentials(credentials)
      @conn = Faraday.new(url: base_url) do |faraday|
        faraday.response :logger if verbose       # write requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
    end

    def setup_credentials(_credentials)
      # dummy implementation, if no credentials are required
      true
    end
  end
end
