# frozen_string_literal: true

module DataCycleCore
  class ImportJob < ApplicationJob
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks

    REFERENCE_TYPE = 'download_import'

    queue_as :importers

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      [self.class::REFERENCE_TYPE, *arguments[1..]].compact_blank.join('_')
    end

    after_enqueue do |_|
      external_system = ExternalSystem.find(delayed_reference_id)
      external_system.data ||= {}
      external_system.data["last_#{delayed_reference_type}_job_id"] = @provider_job_id
      external_system.data["last_#{delayed_reference_type}_failed"] = false
      external_system.data["last_#{delayed_reference_type}_exception"] = nil
      external_system.save
    end

    before_perform do |_|
      external_system = ExternalSystem.find(delayed_reference_id)
      external_system.data ||= {}
      external_system.data["last_#{delayed_reference_type}_failed"] = false
      external_system.data["last_#{delayed_reference_type}_exception"] = nil
      external_system.save!
    end

    def perform(uuid, mode = nil)
      options = {}
      options[:mode] = mode if mode.present?

      pid = Process.fork do
        external_system = ExternalSystem.find(uuid)
        type = delayed_reference_type.start_with?('download') ? 'download' : 'import'

        if block_given?
          yield(external_system)
        else
          if external_system.config.key?('download_config')
            type = 'download'
            success = external_system.download(options)
          else
            success = true
          end

          type = 'import'
          external_system.import(options) if success
        end
      rescue StandardError => e
        ActiveSupport::Notifications.instrument "#{self.class.name.demodulize.underscore}_failed.datacycle", {
          exception: e,
          external_system:,
          type:
        }
        external_system.data ||= {}
        external_system.data["last_#{delayed_reference_type}_failed"] = true
        external_system.data["last_#{delayed_reference_type}_exception"] = {
          'message' => "#{e.message} (#{Time.zone.now})",
          'backtrace' => e.backtrace,
          'class' => e.class.to_s,
          'type' => type
        }
        external_system.save!
      end

      Process.waitpid(pid)

      external_system = ExternalSystem.find(uuid).reload

      return unless external_system.data["last_#{delayed_reference_type}_failed"]

      exception_hash = external_system.data["last_#{delayed_reference_type}_exception"]

      if exception_hash.is_a?(::Hash)
        exception = exception_hash['class'].safe_constantize.new(exception_hash['message'])
        exception.set_backtrace(exception_hash['backtrace'])
        raise exception
      elsif exception_hash.is_a?(::String)
        raise exception_hash
      end
    end
  end
end
