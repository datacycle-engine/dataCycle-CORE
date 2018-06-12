# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module ImportSpots
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale)
          mongo_item.all
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            if raw_data&.dig('attributes', 'image').present?
              DataCycleCore::Generic::Common::ImportFunctions.process_step(
                utility_object: utility_object,
                raw_data: raw_data,
                transformation: DataCycleCore::Generic::Xamoom::Transformations.xamoom_to_image,
                default: { content_type: DataCycleCore::CreativeWork, template: 'Bild' },
                config: options.dig(:import, :transformations, :image)
              )
            end
            DataCycleCore::Generic::Common::ImportFunctions.process_step(
              utility_object: utility_object,
              raw_data: raw_data,
              transformation: DataCycleCore::Generic::Xamoom::Transformations.xamoom_to_poi(utility_object.external_source.id),
              default: { content_type: DataCycleCore::Place, template: 'Örtlichkeit' },
              config: options.dig(:import, :transformations, :spot)
            )
          end
        end
      end
    end
  end
end
