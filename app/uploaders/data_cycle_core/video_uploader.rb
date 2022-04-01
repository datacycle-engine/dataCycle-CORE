# frozen_string_literal: true

require 'streamio-ffmpeg'

module DataCycleCore
  class VideoUploader < CommonUploader
    include CarrierWave::MiniMagick

    version :thumb_preview do
      process create_thumb: [300, 300]
      process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.png"
      end
    end

    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym }, :format).presence || ['avi', 'mov', 'mp4', 'mpeg', 'mpg', 'wmv']
    end

    def create_thumb(width, height)
      movie = FFMPEG::Movie.new(current_path)
      dirname = File.dirname(current_path)
      thumb_path = "#{File.join(dirname, File.basename(path, File.extname(path)))}.png"
      movie.screenshot(thumb_path, seek_time: movie.try(:duration).to_i < 5 ? movie.try(:duration).to_i / 2 : 5)
      sc = ::MiniMagick::Image.open(thumb_path)
      sc.resize "#{width}x#{height}"
      sc.write(thumb_path)
      File.rename thumb_path, current_path
    end

    def metadata
      movie = FFMPEG::Movie.new(current_path)
      movie.metadata
    end

    def convert_format(new_format)
      encode_video(new_format.to_sym) if extension_white_list.include?(new_format.to_s)
    end

    def encode_video(format)
      cached_stored_file! unless cached?

      dir = File.dirname(current_path)
      movie = FFMPEG::Movie.new(current_path)

      tmp_file = File.join(dir, "tmp.#{format}")
      options = {
        resolution: '1280x720',
        video_codec: 'libx264',
        frame_rate: 29.97,
        video_bitrate: 1500,
        # video_bitrate_tolerance:100,
        # aspect: '16:9',
        keyframe_interval: 90,
        x264_vprofile: 'main',
        x264_preset: 'slow',
        audio_codec: 'aac',
        audio_bitrate: 128,
        audio_sample_rate: 22_050,
        audio_channels: 2,
        threads: 2,
        custom: ['-pix_fmt', 'yuv420p', '-movflags', '+faststart']
      }
      transcoder_options = { preserve_aspect_ratio: :height }
      movie.transcode(tmp_file, options, transcoder_options) { |progress| Rails.logger.info progress }

      FileUtils.mv(tmp_file, current_path)
    end
  end
end
