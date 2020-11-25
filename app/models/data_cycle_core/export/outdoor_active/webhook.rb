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
          data.add_external_system_data(@external_system, nil, 'error', nil, false)
          raise DataCycleCore::Generic::Common::Error::GenericError, "OutdoorActive sync job is failed(error), #{@external_system_data}"
        rescue DataCycleCore::Generic::Common::Error::GenericError => e
          Appsignal.send_error(e, nil, 'background')
        end

        def failure(_job)
          data = DataCycleCore::Thing.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'failure', nil, false)
          raise DataCycleCore::Generic::Common::Error::GenericError, "OutdoorActive sync job is failed(failure), #{@external_system_data}"
        rescue DataCycleCore::Generic::Common::Error::GenericError => e
          Appsignal.send_error(e, nil, 'background')
        end

        def perform
          data = DataCycleCore::Thing.find(@data.id)
          job_result = @endpoint.send(@request, data: data, external_system_data: @external_system_data)
          external_key = job_result.dig('outdoor_active_id')

          case job_result.dig('job_status')
          when 'waiting'
            data.add_external_system_data(@external_system, job_result, 'pending', 'export', external_key, false)
          when 'running'
            data.add_external_system_data(@external_system, job_result, 'pending', 'export', external_key, false)
            raise DataCycleCore::Generic::Common::Error::GenericError, "OutdoorActive job is still running with id #{job_result.dig('job_id')}"
          when 'jobnotfound', 'failed'
            data.add_external_system_data(@external_system, job_result, 'failure', 'export', external_key, false)
          when 'done'
            data.add_external_system_data(@external_system, job_result, 'success', 'export', external_key, false)
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
