# frozen_string_literal: true

module DataCycleCore
  class ImportJob < ApplicationJob
    IMPORT_TYPE = 'download_import'

    # queue is configurable per external system via default_options['queue'] (defaults to :importers)
    queue_as { ExternalSystem.find_by(id: arguments.first)&.import_queue || :importers }
    # download and import of the same external system exclude each other via the shared group; the
    # lock is refreshed every duration/3 while the job runs (see +with_extended_concurrency_lock+),
    # so the duration only has to outlast a single step, not the whole import. Nothing refreshes it
    # while the job waits for a free importer worker, so a wait longer than this expires it and lets
    # the duplicate through — accepted: it then runs after this job rather than alongside it
    limits_concurrency key: ->(*args) { args[0] }, group: :importers, duration: 15.minutes
    # the importer list is the one part of the dashboard that shows individual jobs and spins for the
    # running ones, so its jobs are worth a refresh when they start
    self.broadcast_dashboard_on_start = true

    # Whether this job runs the given step. ImportJob itself runs both; its subclasses narrow it down
    # to one. The mode suffix +import_type+ appends never mentions a step, so IMPORT_TYPE is enough —
    # this is what the delayed_job era spelled as +delayed_reference_type ILIKE '%<type>%'+.
    # @param type [String, Symbol] 'download' or 'import'
    # @return [Boolean]
    def self.runs?(type)
      self::IMPORT_TYPE.include?(type.to_s)
    end

    def import_type
      [self.class::IMPORT_TYPE, *arguments[1..]].compact_blank.join('_')
    end

    before_perform :reset_last_status

    def external_system_id
      arguments[0].to_s
    end

    def perform(uuid, mode = nil)
      options = {}
      options[:mode] = mode if mode.present?
      external_system = ExternalSystem.find(uuid)
      type = import_type.start_with?('download') ? 'download' : 'import'

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
      # the external system itself is what could not be found: there is nothing to report the
      # failure on, and discard_on drops a RecordNotFound anyway — reporting would only raise a
      # second one from inside this rescue and mask the original
      raise if external_system.nil?

      ActiveSupport::Notifications.instrument "#{self.class.name.demodulize.underscore}_failed.datacycle", {
        exception: e,
        external_system:,
        type:,
        namespace: 'importer'
      }
      update_last_error(external_system, e)
      raise
    end

    private

    # Deliberately a before_perform rather than the after_enqueue of the delayed_job era: the id is
    # a breadcrumb for looking the run up in solid_queue_jobs afterwards, and the run that matters is
    # the one that actually started, not one that may still be waiting behind its concurrency lock.
    # provider_job_id is the solid_queue_jobs.id here — SolidQueue::ClaimedExecution#perform merges it
    # into the payload before executing, so it is set by the time this callback runs.
    def reset_last_status
      external_system = ExternalSystem.find(external_system_id)
      external_system.data ||= {}
      external_system.data["last_#{import_type}_job_id"] = provider_job_id
      external_system.data["last_#{import_type}_failed"] = false
      external_system.data["last_#{import_type}_exception"] = nil
      external_system.save!
    end

    def update_last_error(external_system, exception)
      external_system.data ||= {}
      external_system.data["last_#{import_type}_failed"] = true
      external_system.data["last_#{import_type}_exception"] = exception.try(:to_yaml)
      external_system.save!
    end
  end
end
