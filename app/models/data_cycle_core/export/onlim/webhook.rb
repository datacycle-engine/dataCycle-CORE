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
          data = @data
          load_data = DataCycleCore::Thing.where(id: data.id)
          data = load_data&.first if load_data.present?
          job_result = @endpoint.send(@request, data: data, external_system_data: @external_system_data)

          return if @request == :delete_request # data is already deleted ...

          external_key = data.id
          log(job_result, data.id) unless job_result.dig('message', 'verificationReport', 'isValid')

          case job_result.dig('job_status')
          when 'pending'
            data.add_external_system_data(@external_system, job_result, 'pending', 'export', external_key, false)
            raise DataCycleCore::Generic::Common::Error::GenericError, "Onlim job is still running with id #{job_result.dig('job_id')}" if @request == :job_status_request
          when 'failed'
            data.add_external_system_data(@external_system, job_result, 'failure', 'export', external_key, false)
            if job_result.dig('message', 'existingObjects') && job_result.dig('job_operation') == 'CREATE'
              existing_ids = job_result.dig('message', 'existingObjectIds').map { |id| id.split('/')&.last }
              return if existing_ids.include?(data.id)
              # --> do create again without already existingObjects
              DataCycleCore::Export::Onlim::Functions.update(utility_object: DataCycleCore::Export::PushObject.new(external_system: @external_system), data: data)
            elsif job_result.dig('message', 'existingObjects') && job_result.dig('job_operation') == 'UPDATE'
              # --> Problem with update ...
            end
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
