# frozen_string_literal: true

module DataCycleCore
  class ImageUploader < CommonUploader
    # Include RMagick or MiniMagick support:
    # include CarrierWave::RMagick
    include CarrierWave::MiniMagick

    version :thumb_preview do
      process convert: 'jpg'
      # process :colorspace => 'rgb'
      process resize_to_fit: [300, 300]

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end
  end
end
