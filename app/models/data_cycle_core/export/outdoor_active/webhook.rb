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

        def error(_job, _exception)
          data = DataCycleCore::Thing.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'error')
        end

        def failure(_job)
          data = DataCycleCore::Thing.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'failure')
        end

        def perform
          data = DataCycleCore::Thing.find(@data.id)
          job_result = @endpoint.send(@request, data: data, external_system_data: @external_system_data)
          data.add_external_system_data(@external_system, job_result)
          raise DataCycleCore::Generic::Common::Error::GenericError, "OutdoorActive job is still running with job_status #{job_result}" if job_result.dig('outdoor_active_id').blank? && job_result.dig('job_status').present?

          data.add_external_system_data(@external_system, nil, 'success') if job_result.dig('job_status') == 'done'
        end

        def queue_name
          "outdoor_active_#{@data.id}"
        end
      end
    end
  end
end
