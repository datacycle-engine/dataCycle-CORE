# frozen_string_literal: true

module DataCycleCore
  module CustomVideoPreviewer
    def preview(**options)
      video_options = {start: 2}
      download_blob_to_tempfile do |input|
        draw_relevant_frame_from(input, video_options: video_options) do |output|
          yield io: output, filename: "#{blob.filename.base}.jpg", content_type: "image/jpeg", **options
        end
      end
    end

    def draw_relevant_frame_from(file, video_options: {}, &block)
      video_arguments = Shellwords.split(ActiveStorage.video_preview_arguments)
      if video_options.dig(:start).present?
        start = video_options.dig(:start)&.to_i
        start_time = (Time.zone.now.beginning_of_day + start.seconds).strftime("%H:%M:%S")
        video_arguments << '-ss'
        video_arguments << start_time
      end
      draw self.class.ffmpeg_path, "-i", file.path, *video_arguments, "-", &block
    end
  end
end

ActiveStorage::Previewer::VideoPreviewer.prepend(DataCycleCore::CustomVideoPreviewer)
