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

          case job_result.dig('job_status')
          when 'waiting'
            data.add_external_system_data(@external_system, job_result, 'pending')
          when 'running'
            data.add_external_system_data(@external_system, job_result, 'pending')

            raise DataCycleCore::Generic::Common::Error::GenericError, "OutdoorActive job is still running with id #{job_result.dig('job_id')}"
          when 'jobnotfound', 'failed'
            data.add_external_system_data(@external_system, job_result, 'failure')
          when 'done'
            data.add_external_system_data(@external_system, nil, 'success')
          else
            raise DataCycleCore::Generic::Common::Error::GenericError, "Unkown job status: #{job_result.dig('job_status')}"
          end
        end

        def reference_type
          "outdoor_active_#{@data.id}"
        end
      end
    end
  end
end
