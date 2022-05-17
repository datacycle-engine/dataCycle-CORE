# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Import
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge({ "dump.#{locale}.mediaassettype.text": '501' }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::Eyebase::ImportKeywords.process_content(
              utility_object: utility_object,
              raw_data: raw_data,
              locale: locale,
              options: utility_object.external_source.config.dig('import_config', 'keywords') || 'Eyebase - Tags'
            )

            # find thing from ftp export with id parsed from original_filename
            thing_id = File.basename(raw_data.dig('original_filename', '#cdata-section').to_s, '.*')
            if thing_id.uuid? && (thing = DataCycleCore::Thing.find_by(id: thing_id, external_source_id: nil, external_key: nil)).present?
              thing.update_columns(external_source_id: utility_object.external_source.id, external_key: raw_data.dig('item_id', 'text'))
            end

            DataCycleCore::Generic::Eyebase::Processing.process_media_asset(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :media_asset)
            )
          end
        end
      end
    end
  end
end
