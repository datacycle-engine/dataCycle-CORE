# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module ImportWebcam
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
            pg = raw_data.dig('config', 'pg')
            cam_host = raw_data.dig('config', 'cam_host')
            cam_details = raw_data&.dig('co', 'pl', 'pcs', 'pc')&.detect { |i| i.dig('t') == '1' }
            return if cam_details.blank?
            return unless cam_details.dig('pci').is_a?(::Array)

            if cam_details.dig('is').present?
              DataCycleCore::Generic::FeratelWebcam::Processing.process_image(
                utility_object,
                cam_details.dig('is').merge({ 'rid' => cam_details['rid'], 'type' => 'is', 'url_key' => 'is' }),
                options.dig(:import, :transformations, :image)
              )
            end

            if cam_details.dig('h').present?
              DataCycleCore::Generic::FeratelWebcam::Processing.process_image(
                utility_object,
                cam_details.dig('h').merge({ 'rid' => cam_details['rid'], 'type' => 'h', 'url_key' => 's' }),
                options.dig(:import, :transformations, :image)
              )
            end

            ['24', '25'].each do |item|
              video_data =
                case item
                when '24'
                  { 'type' => 'Large', 'file_format' => 'mp4', 'width' => 1920, 'height' => 1080 }
                when '25'
                  { 'type' => 'Small', 'file_format' => 'mp4', 'width' => 640, 'height' => 360 }
                end
              url_hash = cam_details.dig('pci').detect { |ii| ii.dig('t') == item }
              next if url_hash.blank?
              thumbnail_url = cam_details.dig('pci').detect { |ii| ii.dig('t') == '10' }&.dig('v')
              DataCycleCore::Generic::FeratelWebcam::Processing.process_video(
                utility_object,
                { 'item' => item, 'url' => url_hash.dig('v'), 'thumbnail_url' => thumbnail_url, 'rid' => cam_details['rid'], 'video_data' => video_data },
                options.dig(:import, :transformations, :image)
              )
            end

            DataCycleCore::Generic::FeratelWebcam::Processing.process_place(
              utility_object,
              cam_details,
              options.dig(:import, :transformations, :place)
            )

            DataCycleCore::Generic::FeratelWebcam::Processing.process_webcam(
              utility_object,
              cam_details.merge({ 'pg' => pg, 'cam_host' => cam_host }),
              options.dig(:import, :transformations, :webcam)
            )
          end
        end
      end
    end
  end
end
