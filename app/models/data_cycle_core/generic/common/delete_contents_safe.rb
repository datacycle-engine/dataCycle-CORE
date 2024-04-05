# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DeleteContentsSafe
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        def self.load_contents(mongo_item, locale, _source_filter)
          # can only delete marked data --> no source_filter
          mongo_item.where({ "dump.#{locale}.deleted_at": { '$exists': true } })
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          unless options.dig(:mode).try(:to_s) == 'full'
            last_successful_import = utility_object.external_source.last_successful_import || Time.zone.now - 20.years
            last_successful_download = utility_object.external_source.last_successful_download || Time.zone.now - 20.years
            last_success = [last_successful_import, last_successful_download].compact.min
            return if last_success.present? && last_success > raw_data.dig('deleted_at').in_time_zone
          end

          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')
            raise "No external id found! Item:#{raw_data.dig('Id')}, external_key_path: #{external_key_path}" if raw_data.dig(*external_key_path).blank?
            external_key = [options.dig(:import, :external_key_prefix), raw_data.dig(*external_key_path)].join

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
              if content.available_locales.one? && content.available_locales.include?(I18n.locale)
                duplicates = content.external_system_syncs.where(sync_type: 'duplicate')
                if options.dig(:import, :delete_all_duplicates)
                  duplicates.destroy_all
                  oldest_import_duplicate = nil
                else
                  # look for oldest with import_config
                  oldest_import_duplicate = duplicates.joins(:external_system).where("external_systems.config ->> 'import_config' IS NOT NULL").order(created_at: :asc).first
                end
              end

              if oldest_import_duplicate.nil?
                content.try(:destroy_content, save_history: true, destroy_linked: true, destroy_locale: true) # delete only a particular translation!
              else
                content.update_columns(external_source_id: oldest_import_duplicate.external_system_id, external_key: oldest_import_duplicate.external_key) unless DataCycleCore::Thing.exists?(
                  external_source_id: oldest_import_duplicate.external_system_id,
                  external_key: oldest_import_duplicate.external_key
                )
                oldest_import_duplicate.destroy
              end
            end
          end
        end
      end
    end
  end
end
