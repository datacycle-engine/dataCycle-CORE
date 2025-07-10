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

      private

      def invalidate_last_download_and_import
        remove_instance_variable(:@last_import_status) if instance_variable_defined?(:@last_import_status)
        remove_instance_variable(:@last_download_status) if instance_variable_defined?(:@last_download_status)
      end

      def last_status(type)
        return 'deactivated' if deactivated

        stati = send(:"#{type}_accessors").map { |k| send(k) }.compact_blank.pluck('status')

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

      def last_status_legacy(type)
        last_legacy_status = send(:"last_#{type}") == send(:"last_successful_#{type}") ? 'finished' : 'error' if !deactivated && (send(:"last_#{type}") || send(:"last_successful_#{type}"))
        last_legacy_status = 'running' if last_legacy_status == 'error' &&
                                          (type == :import ? last_download_status != 'running' : true) &&
                                          Delayed::Job.where('delayed_reference_type ILIKE ?', "%#{type}%")
                                            .where(
                                              queue: 'importers',
                                              delayed_reference_id: id,
                                              failed_at: nil
                                            )
                                            .where.not(locked_by: nil)
                                            .exists?

        last_legacy_status
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
