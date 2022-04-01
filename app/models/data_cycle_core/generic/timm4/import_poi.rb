# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Timm4
      module ImportPoi
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}": { '$exists' => true }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            if raw_data['img'].present?
              DataCycleCore::Generic::Timm4::Processing.process_image(
                utility_object,
                {
                  'content_url' => raw_data['img'],
                  'img_description' => raw_data['imgDescription']
                },
                options.dig(:import, :transformations, :image)
              )
            end

            Array.wrap(raw_data['images']).each do |link|
              DataCycleCore::Generic::Timm4::Processing.process_image(
                utility_object,
                {
                  'content_url' => link
                },
                options.dig(:import, :transformations, :image)
              )
            end

            DataCycleCore::Generic::Timm4::Processing.process_poi(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :poi)
            )
          end
        end
      end
    end
  end
end
