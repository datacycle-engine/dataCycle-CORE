# frozen_string_literal: true

module DataCycleCore
  module Storage
    module Previewer
      class VideoPreviewer < ActiveStorage::Previewer::VideoPreviewer
        def preview(**options)
          download_blob_to_tempfile do |input|
            draw_relevant_frame_from(input, additional_video_arguments: video_options_from_thing) do |output|
              yield io: output, filename: "#{blob.filename.base}.jpg", content_type: 'image/jpeg', **options
            end
          end
        end

        private

        def draw_relevant_frame_from(file, additional_video_arguments: '', &block)
          video_arguments = Shellwords.split(ActiveStorage.video_preview_arguments + additional_video_arguments)
          draw self.class.ffmpeg_path, '-i', file.path, *video_arguments, '-', &block
        end

        def video_options_from_thing
          thing = blob&.attachments&.first&.record&.thing
          start_time = thing&.try(:preview_image_start_time)
          return '' if start_time.blank? || (start_time > thing.duration)

          start_time = (Time.zone.now.beginning_of_day + start_time.to_i.seconds).strftime('%H:%M:%S')
          " -ss #{start_time}"
        end
      end
    end
  end
end
