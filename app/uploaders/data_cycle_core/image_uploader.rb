# frozen_string_literal: true

require 'phash/image'

module DataCycleCore
  class ImageUploader < CommonUploader
    include CarrierWave::MiniMagick

    process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?

    version :thumb_preview do
      process :remove_animation
      process convert: 'jpg'
      process resize_to_fit: [300, 300]
      process colorspace: 'RGB'
      process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?
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

    def auto_tag
      vision = Google::Cloud::Vision.new project_id: 'KW_Media_Archive_Vision'
      translation_service = Google::Cloud::Translate.new(project_id: 'KW_Media_Archive_Vision')

      labels = vision.image(file.thumb_lightbox.file.file).labels

      labels.each do |label|
        Tag.find_or_create_by(name: label.description) do |tag|
          tag.language = 'en'

          translation = translation_service.translate(tag.name, to: 'de')
          unless tag.name.casecmp(translation).zero?
            begin
              translated_tag = Tag.find_or_create_by(name: translation.text, language: 'de')
              tag.original_id = translated_tag.id
            rescue StandardError => e
              puts e
            end
          end
        end
      end

      medium.tag_list.add(labels.map(&:description))
      medium.save
      labels
    rescue => e
      puts e
    end
  end
end
