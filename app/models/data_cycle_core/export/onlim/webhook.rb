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

        def error(_job, exception)
          data = DataCycleCore::Thing.find(@data.id)
          status = @request == :job_status_request ? 'pending' : 'error'
          metadata = {
            exception: {
              timestamp: Time.zone.now,
              message: exception.message.dup.force_encoding('UTF-8'),
              text: exception.try(:response)&.dig(:body)&.dup&.force_encoding('UTF-8')
            }
          }
          update_sync_data(content: data, external_system: @external_system, status: status, metadata: metadata)
        end

        def failure(_job)
          data = DataCycleCore::Thing.find(@data.id)
          update_sync_data(content: data, external_system: @external_system, status: 'failure')
          # data.add_external_system_data(@external_system, nil, 'failure', 'export', @data.id, false)
        end

        def perform
          data = @data
          load_data = DataCycleCore::Thing.where(id: data.id)
          data = load_data&.first if load_data.present?
          job_result = @endpoint.send(@request, data: data, external_system_data: @external_system_data)

          return if @request == :delete_request # data is already deleted ...

          # external_key = data.id
          log(job_result, data.id) unless job_result.dig('message', 'verificationReport', 'isValid')

          case job_result.dig('job_status')
          when 'pending'
            update_sync_data(content: data, external_system: @external_system, status: 'pending', metadata: job_result)
            # data.add_external_system_data(@external_system, job_result, 'pending', 'export', external_key, false)
            raise DataCycleCore::Generic::Common::Error::GenericError, "Onlim job is still running with id #{job_result.dig('job_id')}" if @request == :job_status_request
          when 'failed'
            update_sync_data(content: data, external_system: @external_system, status: 'failed', metadata: job_result)
            # data.add_external_system_data(@external_system, job_result, 'failure', 'export', external_key, false)
          when 'success'
            update_sync_data(content: data, external_system: @external_system, status: 'success', metadata: job_result)
            # data.add_external_system_data(@external_system, job_result, 'success', 'export', external_key, false)
          else
            raise DataCycleCore::Generic::Common::Error::GenericError, "Unkown job status: #{job_result.dig('job_status')}"
          end
        end

        def reference_type
          "onlim_#{@request}_#{@data.id}"
        end

        def update_sync_data(content:, external_system:, status:, metadata: nil)
          # content.add_external_system_data(external_system, metadata, status, 'export', external_key, false)
          find_by_hash = {
            external_system: external_system,
            sync_type: 'export',
            external_key: content.id,
            use_key: false
          }

          content
            .external_system_sync_by_system(find_by_hash)
            .tap do |s|
              s.status = status
              s.data = (s.data || {}).merge(metadata) if metadata.present?
              s.external_key = content.id
              if status == 'success'
                s.last_successful_sync_at = Time.zone.now
                s.data.delete('exception') if s.data.key?('exception')
              else
                s.last_sync_at = Time.zone.now
              end
              s.save!
            end
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
