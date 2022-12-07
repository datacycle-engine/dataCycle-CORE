# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      class Webhook < DataCycleCore::Export::Common::Webhook
        def initialize(data:, endpoint:, request:, external_system:, external_system_data:)
          @data = data
          @endpoint = endpoint
          @external_system = external_system
          @external_system_data = external_system_data || {}
          @request = request
        end

        def error(_job, _exception)
          # binding.pry
          data = DataCycleCore::Thing.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'error', 'export', nil, false)
        end

        def failure(_job)
          data = DataCycleCore::Thing.find(@data.id)
          data.add_external_system_data(@external_system, nil, 'failure', 'export', nil, false)
        end

        def perform
          # binding.pry
          data = @data
          load_data = DataCycleCore::Thing.where(id: data.id)
          data = load_data&.first if load_data.present?
          job_result = @endpoint.send(@request, data: data, external_system_data: @external_system_data)
          return if @request == :delete_request # data is already deleted ...

          external_key = data.id
          log(job_result, data.id) if job_result.dig('errors').present? || job_result.dig('warnings')

          case job_result.dig('job_status')
          when 'waiting'
            data.add_external_system_data(@external_system, job_result, 'pending', 'export', external_key, false)
          when 'running'
            data.add_external_system_data(@external_system, job_result, 'pending', 'export', external_key, false)
            raise DataCycleCore::Generic::Common::Error::GenericError, "Onlim job is still running with id #{job_result.dig('job_id')}"
          when 'jobnotfound', 'failed'
            data.add_external_system_data(@external_system, job_result, 'failure', 'export', external_key, false)
          when 'success'
            data.add_external_system_data(@external_system, job_result, 'success', 'export', external_key, false)
          else
            raise DataCycleCore::Generic::Common::Error::GenericError, "Unkown job status: #{job_result.dig('job_status')}"
          end
        end

        def reference_type
          "onlim_#{@request}_#{@data.id}"
        end

        def log(message, id)
          init_logging do |logger|
            logger.info(message, id)
          end
        end

        def init_logging
          logging = DataCycleCore::Generic::Logger::LogFile.new(:outdoor_active_sync_errors)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end
    end
  end
end
