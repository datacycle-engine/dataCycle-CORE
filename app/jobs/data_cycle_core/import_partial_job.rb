# frozen_string_literal: true

module DataCycleCore
  class ImportPartialJob < ApplicationJob
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks

    queue_as :importers

    def delayed_reference_id
      arguments[0].to_s
    end

    def delayed_reference_type
      "import_#{arguments[1]}"
    end

    def perform(uuid, import_name, mode = nil)
      external_source = ExternalSystem.find(uuid)
      options = {}
      options[:mode] = mode if mode.present?
      pid = Process.fork do
        ExternalSystem.find(uuid).import_single(import_name, options)
      rescue StandardError => e
        ActiveSupport::Notifications.instrument "#{self.class.name.demodulize.underscore}_failed.datacycle", {
          exception: e,
          external_system: external_source
        }
        external_source.config['last_import_failed'] = true
        external_source.config['last_import_exception'] = "#{e} (#{Time.zone.now})"
        external_source.save!
      end
      Process.waitpid(pid)

      external_source.reload
      ActiveRecord::Base.establish_connection
      raise external_source.config.dig('last_import_exception') if external_source.config.dig('last_import_failed')
    end
  end
end
