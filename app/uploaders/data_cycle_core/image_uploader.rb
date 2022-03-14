# frozen_string_literal: true

require 'phash/image'
require 'mini_exiftool_vendored'

module DataCycleCore
  class ImageUploader < CommonUploader
    include CarrierWave::MiniMagick

    WEB_SAVE_MIME_TYPES = [
      'image/gif',
      'image/png',
      'image/jpeg'
    ].freeze

    DEFAULT_MIME_TYPE = 'image/jpeg'

    process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?

    version :thumb_preview do
      process :remove_animation
      process convert: 'jpg'
      process resize_to_fit: [300, 300]
      process colorspace: 'sRGB'
      process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?
      process :set_phash

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end

    version :web do
      process :remove_animation
      process resize_to_limit: [2048, 2048]
      process :convert_for_web
      process colorspace: 'sRGB'
      process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?
      process content_type: true

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        MiniMime.lookup_by_content_type(MiniMime.lookup_by_filename(for_file.to_s)&.content_type.to_s)&.extension

        file_ext = MiniMime.lookup_by_content_type(MiniMime.lookup_by_filename(for_file.to_s)&.content_type.to_s)&.extension
        file_ext = MiniMime.lookup_by_content_type(DEFAULT_MIME_TYPE)&.extension if WEB_SAVE_MIME_TYPES.exclude?(MiniMime.lookup_by_filename(for_file.to_s)&.content_type.to_s)

        "#{version_name}_#{basename}.#{file_ext}"
      end
    end

    def url(transformation = {})
      content = model&.thing

      return super if content.nil?

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

        local_asset_url(host: asset_host, klass: model.class.to_s.demodulize.underscore, id: model.id, version: (version_name || 'original'), file: "#{file_name}.#{file&.extension || File.extname(model.name.to_s).delete('.')}", transformation: transformation)
      end
    end

    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym }, :format).presence || ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif', 'tiff']
    end

    def metadata
      image = ::MiniMagick::Image.new(current_path)
      colorspace = { ImColorSpace: image.data.dig('colorspace') }
      exif_data = MiniExiftool.new(current_path, { replace_invalid_chars: true })
      exif_data
        .to_hash
        .transform_values { |value| value.is_a?(String) ? value.delete("\u0000") : value }
        .merge!(colorspace)
    end

    def set_phash
      return if model.duplicate_check&.dig('phash').present? && model.duplicate_check&.dig('phash')&.positive?

      model.update_column(:duplicate_check, { phash: Phash::Image.new(file.file).try(:compute_phash).try(:data) })
    end

    def remove_animation
      manipulate!(&:collapse!) if content_type == 'image/gif'
    end

    def content_type(websave = false)
      mime_type = MiniMime.lookup_by_filename(current_path.to_s)&.content_type
      mime_type = MiniMime.lookup_by_content_type(DEFAULT_MIME_TYPE) if websave && WEB_SAVE_MIME_TYPES.exclude?(mime_type.to_s)
      file.instance_variable_set(:@content_type, mime_type.to_s)
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

    def convert_for_web
      manipulate! do |img|
        img.format(MiniMime.lookup_by_content_type(DEFAULT_MIME_TYPE)&.extension) unless WEB_SAVE_MIME_TYPES.include?(file.content_type)
        img.density 96
        img
      end
    end
  end
end
