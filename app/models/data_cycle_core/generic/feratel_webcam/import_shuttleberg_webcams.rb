# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module ImportShuttlebergWebcams
        def self.import_data(utility_object:, options:)
          I18n.with_locale(:de) do
            webcams = {
              'cam1' => 'Chill House - Absolut Park',
              'cam2' => 'Sun House - Flachauwinkl',
              'cam3' => 'Powder Shuttle Bergstation',
              'cam4' => 'Absolut Shuttle Bergstation',
              'cam5' => 'Lumberjack Shuttle Talstation'
            }
            webcams.each do |cam, name|
              data = {
                'content_url' => "https://api.shuttleberg.com/api/v1/webcams/#{cam}.mp4",
                'url' => 'https://www.shuttleberg.com',
                'thumbnail_url' => "https://api.shuttleberg.com/api/v1/webcams/#{cam}.jpg",
                'name' => name,
                'external_key' => "Shuttleberg - #{cam}"
              }
              DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
                utility_object: utility_object,
                template: DataCycleCore::Thing.find_by(template: true, template_name: 'Webcam'),
                data: data,
                local: false,
                config: options.dig(:import, :transformations, :webcam)
              )
            end
          end
        end
      end
    end
  end
end
