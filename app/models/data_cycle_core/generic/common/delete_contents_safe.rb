# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DeleteContentsSafe
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.delete_data(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        def self.load_contents(filter_object:)
          filter_object.with_deleted.query
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')
            external_keys = raw_data.filter_map { |data| data.dump[locale]&.dig(*external_key_path) }
            external_keys.map! { |key| [options.dig(:import, :external_key_prefix), key].join } if options.dig(:import, :external_key_prefix)

            contents = DataCycleCore::Thing.where(
              external_source_id: utility_object.external_source.id,
              external_key: external_keys
            )

            template_names = Array.wrap(options.dig(:import, :template_name))
            if template_names.present?
              all_templates = DataCycleCore::ThingTemplate.where.not(content_type: 'embedded').pluck(:template_name)

              raise "Template names not found: #{template_names - all_templates}" if (template_names - all_templates).any?
              contents = contents.where(template_name: template_names)
            end

            # for all contents not found, clean up the external_system_sync
            external_keys_missing_contents = external_keys - contents.pluck(:external_key)
            ess = DataCycleCore::ExternalSystemSync.where(
              external_system_id: utility_object.external_source.id,
              sync_type: 'duplicate',
              external_key: external_keys_missing_contents,
              syncable_type: 'DataCycleCore::Thing'
            )
            ess.destroy_all

            contents.each do |content|
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
