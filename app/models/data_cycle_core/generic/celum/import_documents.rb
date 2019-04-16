# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module ImportDocuments
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, _locale, source_filter)
          mongo_item.where(source_filter).all
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            case options.dig(:import, :transformations, :asset, :asset_type)
            when 'DataCycleCore::Image'
              DataCycleCore::Generic::Celum::Processing.process_images(
                utility_object,
                raw_data,
                options.dig(:import, :transformations, :asset)
              )
            when 'DataCycleCore::Audio'
              DataCycleCore::Generic::Celum::Processing.process_audio(
                utility_object,
                raw_data,
                options.dig(:import, :transformations, :asset)
              )
            when 'DataCycleCore::Video'
              DataCycleCore::Generic::Celum::Processing.process_video(
                utility_object,
                raw_data,
                options.dig(:import, :transformations, :asset)
              )
            end
          end
        end
      end
    end
  end
end
