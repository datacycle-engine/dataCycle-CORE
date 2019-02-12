# frozen_string_literal: true

require 'phash/image'

module DataCycleCore
  class ImageUploader < CommonUploader
    include CarrierWave::MiniMagick

    version :thumb_preview do
      process :remove_animation
      process convert: 'jpg'
      process resize_to_fit: [300, 300]
      process colorspace: 'RGB'
      process :set_phash

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end

    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore.remove('_uploader').to_sym, :format).presence || ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif', 'tiff']
    end

    def metadata
      image = ::MiniMagick::Image.new(current_path)
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

    def remove_animation
      manipulate! do |img, index|
        img if index.to_i.zero?
      end
    end

    def colorspace(cs)
      manipulate! do |img|
        img.format(img.type.to_s.downcase) do |c|
          c.colorspace cs.to_s
        end
        img = yield(img) if block_given?
        img
      end
    end
  end
end
