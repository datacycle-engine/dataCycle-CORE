# frozen_string_literal: true

module DataCycleCore
  module ExternalSystemExtensions
    module Status
      extend ActiveSupport::Concern

      included do
        after_save_commit :invalidate_last_download_and_import
      end

      def last_import_status
        return @last_import_status if defined? @last_import_status

        @last_import_status = last_status(:import)
      end

      def last_download_status
        return @last_download_status if defined? @last_download_status

        @last_download_status = last_status(:download)
      end

      def last_download_and_import
        {
          last_download:,
          last_download_time:,
          last_import:,
          last_import_time:,
          last_successful_download:,
          last_successful_download_time:,
          last_successful_import:,
          last_successful_import_time:,
          last_download_status:,
          last_import_status:
        }
      end

      def fail_running_steps!
        last_import_step_time_info&.each do |step_key, info|
          next unless info['status'] == 'running'

          timestamp = info['last_try']&.in_time_zone

          update_step_timestamp_end(timestamp, step_key, false)
        end
      end

      private

      def invalidate_last_download_and_import
        remove_instance_variable(:@last_import_status) if instance_variable_defined?(:@last_import_status)
        remove_instance_variable(:@last_download_status) if instance_variable_defined?(:@last_download_status)
      end

      def last_status(type)
        return 'deactivated' if deactivated

        stati = send(:"#{type}_accessors").map { |k| step_info_for(k) }.compact_blank.pluck('status')

        if stati.all?(nil)
          send(:"last_#{type}_status_legacy")
        elsif stati.any?('running')
          'running'
        elsif stati.any?('error')
          'error'
        elsif stati.all?('finished')
          'finished'
        else
          'unknown'
        end
      end

      # Fallback for external systems that report no step info at all. Their only evidence is the
      # last/last_successful timestamp pair, and a first run that is still going looks exactly like a
      # failed one there: last_<type> is set, last_successful_<type> is not. So an 'error' has to be
      # checked against the queue before it is believed — step info is what replaced this, but a
      # system without any never gets it.
      def last_status_legacy(type)
        last_legacy_status = send(:"last_#{type}") == send(:"last_successful_#{type}") ? 'finished' : 'error' if !deactivated && (send(:"last_#{type}") || send(:"last_successful_#{type}"))

        return last_legacy_status unless last_legacy_status == 'error'
        # a running download reports itself; don't show the import it is a prerequisite of as running too
        return last_legacy_status if type == :import && last_download_status == 'running'

        running_import_job?(type) ? 'running' : last_legacy_status
      end

      # Whether a worker is currently executing a +type+ job for this external system. Every
      # ImportJob variant shares the :importers concurrency group, so this matches at most one row.
      # @param type [Symbol] :download or :import
      # @return [Boolean]
      def running_import_job?(type)
        SolidQueue::Job
          .where(concurrency_key: DataCycleCore::ImportJob.new(id).concurrency_key)
          .where.associated(:claimed_execution)
          .pluck(:class_name)
          .any? { |class_name| class_name.safe_constantize.try(:runs?, type) }
      end

      def last_download_status_legacy
        last_status_legacy(:download)
      end

      def last_import_status_legacy
        last_status_legacy(:import)
      end
    end
  end
end
