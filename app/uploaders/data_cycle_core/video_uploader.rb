# frozen_string_literal: true

require 'streamio-ffmpeg'

module DataCycleCore
  class VideoUploader < CommonUploader
    include CarrierWave::MiniMagick

    version :thumb_preview do
      process create_thumb: [300, 300]

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end

    def create_thumb(width, height)
      movie = FFMPEG::Movie.new(current_path)
      dirname = File.dirname(current_path)
      thumb_path = "#{File.join(dirname, File.basename(path, File.extname(path)))}.png"
      movie.screenshot(thumb_path, seek_time: 5)
      sc = ::MiniMagick::Image.open(thumb_path)
      sc.resize "#{width}x#{height}"
      sc.write(thumb_path)
      File.rename thumb_path, current_path
    end

    def exif_data
      movie = FFMPEG::Movie.new(current_path)
      movie.metadata
    end
  end
end
