# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      class Webhook < DataCycleCore::Export::Common::Webhook
        def initialize(data:, endpoint:, request:, external_system:, external_system_data:)
          @data = data
          @endpoint = endpoint
          @external_system = external_system
          @external_system_data = external_system_data || {}
          @request = request
        end

        def perform
          job_result = @endpoint.send(@request, data: @data)
          @data.add_external_system_data(@external_system, @external_system_data.merge(job_result))
        end

        def queue_name
          "outdoor_active_#{@data.id}"
        end
      end
    end
  end
end
