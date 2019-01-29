# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      class Webhook < DataCycleCore::Export::Common::Webhook
        def initialize(data:, endpoint:, external_system:, external_system_data:)
          @data = data
          @endpoint = endpoint
          @external_system = external_system
          @external_system_data = external_system_data
        end

        def perform
          job_id = @endpoint.notification_request(
            data: @data
          )
          @data.add_external_system_data(@external_system, { 'job_id' => job_id, 'external_source_id' => @data.external_source.id })
        end

        def queue_name
          "outdoor_active_#{@data.id}"
        end
      end
    end
  end
end
