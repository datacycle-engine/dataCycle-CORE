# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module ImportWebcamXml
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
            DataCycleCore::Generic::FeratelWebcam::Processing.process_place_xml(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )

            # thumbnail_klein
            DataCycleCore::Generic::FeratelWebcam::Processing.process_image_xml(
              utility_object,
              raw_data
                .slice('rid', 'l')
                .merge({
                  'tn' => 'Thumbnail klein',
                  'url' => 'https://wtvthmb.feratel.com/thumbnails/%<rid>s.jpeg?t=%<type>s&design=v4&dcsdesign=feratel4',
                  'type' => '44'
                }),
              options.dig(:import, :transformations, :image)
            )

            # thumbnail_groß
            DataCycleCore::Generic::FeratelWebcam::Processing.process_image_xml(
              utility_object,
              raw_data
                .slice('rid', 'l')
                .merge({
                  'tn' => 'Thumbnail groß',
                  'url' => 'https://wtvthmb.feratel.com/thumbnails/%<rid>s.jpeg?t=%<type>s&design=v4&dcsdesign=feratel4',
                  'type' => '38'
                }),
              options.dig(:import, :transformations, :image)
            )

            DataCycleCore::Generic::FeratelWebcam::Processing.process_webcam_xml(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :webcam)
            )
          end
        end
      end
    end
  end
end
