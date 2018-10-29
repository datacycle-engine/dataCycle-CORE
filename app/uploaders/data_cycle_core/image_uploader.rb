# frozen_string_literal: true

require 'phash/image'

module DataCycleCore
  class ImageUploader < CommonUploader
    include CarrierWave::MiniMagick

    version :thumb_preview do
      process convert: 'jpg'
      process resize_to_fit: [300, 300]
      process :set_phash

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end

    def extension_white_list
      ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif', 'tiff']
    end

    def metadata
      image = ::MiniMagick::Image.open(current_path)
      image.data
    end

    def duplicate_check
      {
        phash: Phash::Image.new(current_path).try(:compute_phash).try(:data)
      }
    end

    def set_phash
      return if model.duplicate_check&.dig('phash').present? && model.duplicate_check&.dig('phash')&.positive?
      model.duplicate_check = {
        phash: Phash::Image.new(file.file).try(:compute_phash).try(:data)
      }
      model.save!
    end
  end
end
