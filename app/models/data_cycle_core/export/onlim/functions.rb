# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module Functions
        def self.update(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = load_external_system_data(data, external_system) # data.external_system_data(external_system, 'export', nil, false)
          data.add_external_system_data(external_system, nil, 'running', 'export', nil, false)
          log("update -> Export | Onlim | #{external_system.id}", data&.id)

          unless external_system_data&.dig('job_status')&.in?(['pending'])
            webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
              data: OpenStruct.new(id: data.id, template_name: data.template_name), # rubocop:disable Style/OpenStructUse
              external_system: external_system,
              external_system_data: external_system_data,
              endpoint: utility_object.endpoint,
              request: :update_request
            )
            Delayed::Job.enqueue(webhook)
          end

          # ask for job_status
          update_job_status(utility_object: utility_object, data: data)
        end

        def self.update_job_status(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = load_external_system_data(data, external_system)
          log("update_job_status -> Export | Onlim | #{external_system.id}", data&.id)

          webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name), # rubocop:disable Style/OpenStructUse
            external_system: external_system,
            external_system_data: external_system_data,
            endpoint: utility_object.endpoint,
            request: :job_status_request
          )

          Delayed::Job.enqueue(webhook)
        end

        def self.delete(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = data.external_system_data(external_system, 'export', nil, false)
          data.add_external_system_data(external_system, nil, 'deleting', 'export', nil, false)
          log("delete -> Export | Onlim | #{external_system.id}", data&.id)

          webhook = (external_system.config.dig('export_config', 'webhook').presence&.safe_constantize || DataCycleCore::Export::Generic::Webhook).new(
            data: OpenStruct.new(id: data.id, template_name: data.template_name), # rubocop:disable Style/OpenStructUse
            external_system: external_system,
            external_system_data: external_system_data,
            endpoint: utility_object.endpoint,
            request: :delete_request
          )

          Delayed::Job.enqueue(webhook)
        end

        def self.filter(data:, external_system:, method_name:)
          # sync_data = data.external_system_data_all(external_system, 'export', nil, false)
          # job_id = sync_data&.data&.dig('job_id')
          # updated_at = sync_data&.updated_at || Time::LONG_AGO
          DataCycleCore::Export::Generic::Functions.filter(data: data, external_system: external_system, method_name: method_name)
        end

        def self.load_external_system_data(data, external_system)
          sync_data_all = data.external_system_data_all(external_system, 'export', nil, false)
          return if sync_data_all.blank?
          (sync_data_all&.data || {}).merge({ 'external_system_syncs_id' => sync_data_all.id })
        end

        def self.log(message, id)
          init_logging do |logger|
            logger.info(message, id)
          end
        end

        def self.init_logging
          logging = DataCycleCore::Generic::Logger::LogFile.new(:export)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end
    end
  end
end
