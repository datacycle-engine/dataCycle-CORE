# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module ImportImages
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists' => true } }.merge(source_filter))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['teaserImage', 'imageGallery'].each do |entry|
              next if raw_data.dig(entry).blank?
              DataCycleCore::Generic::Pimcore::Processing.process_image(
                utility_object,
                raw_data.dig(entry),
                options.dig(:import, :transformations, :image)
              )
            end
          end
        end
      end
    end
  end
end
