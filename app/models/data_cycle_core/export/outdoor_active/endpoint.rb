# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      class Endpoint < DataCycleCore::Export::Common::Endpoint::GenericEndpoint
        def initialize(**options)
          @host = options.dig(:host)
          @key = options.dig(:key)
        end

        def notification_request(data:)
          # send response
          # response = Faraday.new.get do |req|
          #   req.url File.join([@host])
          #
          #   req.params['key'] = @key
          #   req.params['ids'] = data.id
          # end

          # raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{File.join([@host, @key])} ", response) unless response.success?
          # TODO: save jobId

          job_id = Digest::MD5.hexdigest(data.id)
          job_id
        end
      end
    end
  end
end
