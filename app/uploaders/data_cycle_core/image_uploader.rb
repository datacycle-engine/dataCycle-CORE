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

    def url
      content = model&.things&.first

      return "#{asset_host}/assets/#{model.class.to_s.demodulize.underscore}/#{model.id}/#{version_name || 'original'}/#{File.basename(model.name.to_s, '.*').underscore_blanks}.#{file&.extension || File.extname(model.name.to_s).delete('.')}" if content.nil?

      copyright_holder = content.try(:copyright_holder)&.first
      copyright_year = content.try(:copyright_year)&.to_i
      author = content.try(:author)&.first

      I18n.with_locale(content.first_available_locale) do
        file_name = [
          (content.title.presence || File.basename(model.name.to_s, '.*')),
          (copyright_holder.nil? ? nil : I18n.with_locale(copyright_holder.first_available_locale) { copyright_holder.title }),
          copyright_year,
          (author.nil? ? nil : I18n.with_locale(author.first_available_locale) { author.title })
        ].compact.join('_').underscore_blanks

        "#{asset_host}/assets/#{model.class.to_s.demodulize.underscore}/#{model.id}/#{version_name || 'original'}/#{file_name}.#{file&.extension || File.extname(model.name.to_s).delete('.')}"
      end
    end

    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore.remove('_uploader').to_sym, :format).presence || ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif', 'tiff']
    end

    def metadata
      image = ::MiniMagick::Image.new(current_path)
      image.data
    end

    def set_phash
      return if model.duplicate_check&.dig('phash').present? && model.duplicate_check&.dig('phash')&.positive?

      model.update(duplicate_check: {
        phash: Phash::Image.new(file.file).try(:compute_phash).try(:data)
      })
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
