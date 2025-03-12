# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DeleteContents
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        def self.load_contents(filter_object:)
          filter_object.except(:without_deleted, :without_archived, :with_deleted).with_locale.query
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          last_success = utility_object.external_source.last_try_successful
          raise 'Delete canceled (No successful download detected)!' if last_success.blank?

          last_download = utility_object.external_source.last_try
          raise "Delete canceled (Last download(s) failed)! Last success: #{last_success}, last try: #{last_download}" if last_download.present? && last_success < last_download

          delete_deadline = eval(options.dig(:import, :last_try_successful)) if options.dig(:import, :last_try_successful).present? # rubocop:disable Security/Eval
          if delete_deadline.present? && last_success < delete_deadline
            last_date = last_success.presence || 'never'
            delete_date = delete_deadline.presence || 'not specified'
            raise "No recent successful download detected! Last successful Download: #{last_date}, delete deadline: #{delete_date}"
          end

          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')

            raise "No external id found! Item:#{raw_data['Id']}, external_key_path: #{external_key_path}" if raw_data.dig(*external_key_path).blank?

            external_key = [options.dig(:import, :external_key_prefix), raw_data.dig(*external_key_path)].compact_blank.join

            content = DataCycleCore::Thing.find_by(
              external_source_id: utility_object.external_source.id,
              external_key:
            )

            if content.nil?
              DataCycleCore::ExternalSystemSync.find_by(
                external_system_id: utility_object.external_source.id,
                sync_type: 'duplicate',
                external_key:,
                syncable_type: 'DataCycleCore::Thing'
              )&.destroy
            else
              oldest_duplicate = content.external_system_syncs.where(
                sync_type: 'duplicate',
                syncable_type: 'DataCycleCore::Thing'
              ).order(created_at: :asc).first

              if oldest_duplicate.nil?
                content.try(:destroy_content, save_history: true, destroy_linked: true)
              else
                content.update_columns(external_source_id: oldest_duplicate.external_system_id, external_key: oldest_duplicate.external_key) unless DataCycleCore::Thing.exists?(
                  external_source_id: oldest_duplicate.external_system_id,
                  external_key: oldest_duplicate.external_key
                )
                oldest_duplicate.destroy
              end
            end
          end
        end
      end
    end
  end
end
