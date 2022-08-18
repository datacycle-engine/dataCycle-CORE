# frozen_string_literal: true

require 'mini_magick'
require 'image_processing/mini_magick'
require 'phash/image'
require 'mini_exiftool_vendored'

module DataCycleCore
  class Image < Asset
    if active_storage_activated?
      has_one_attached :file

      cattr_reader :versions, default: {}
      attr_accessor :remote_file_url
      before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }
    else
      mount_uploader :file, ImageUploader
      process_in_background :file
      validates_integrity_of :file
      after_destroy :remove_directory
      delegate :versions, to: :file

      after_create_commit :set_duplicate_hash, if: proc { |image| image.persisted? && file.enable_processing && !image.file.thumb_preview&.file&.exists? }
    end

    def custom_validators
      if self.class.active_storage_activated?
        DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore)&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      else
        DataCycleCore.uploader_validations.dig(file.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym })&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      end
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:image, :format).presence || ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif', 'tiff']
    end

    def update_asset_attributes
      return if file.blank?
      if self.class.active_storage_activated?
        self.content_type = file.blob.content_type
        self.file_size = file.blob.byte_size
        self.name ||= file.blob.filename
        begin
          self.metadata = metadata_from_blob
        rescue JSON::GeneratorError
          self.metadata = nil
        end
        self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
      else
        self.content_type = file.file.content_type
        self.file_size = file.file.size
        self.name ||= file.file.filename
        begin
          self.metadata = file.metadata&.to_utf8 if file.respond_to?(:metadata) && file.metadata.try(:to_utf8)&.to_json.present?
        rescue JSON::GeneratorError
          self.metadata = nil
        end
      end
      self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
    end

    def dimensions_validation(options)
      if self.class.active_storage_activated?
        return if options.dig(:exclude, :format)&.include?(file.filename&.to_s&.split('.')&.last) || file&.attached? == false

        if attachment_changes.present?
          if attachment_changes['file']&.attachable.is_a?(::Hash) && attachment_changes['file']&.attachable&.dig(:io).present?
            # import from local disc
            path_to_tempfile = attachment_changes['file'].attachable.dig(:io).path
          else
            path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
          end
        else
          path_to_tempfile = file.service.path_for(file.key)
        end
        image = ::MiniMagick::Image.new(path_to_tempfile)
      else
        return if options.dig(:exclude, :format)&.include?(file.filename&.to_s&.split('.')&.last) || file&.file.nil?
        image = ::MiniMagick::Image.new(file.file.path)
      end

      options.except(:exclude, :landscape, :portrait).presence&.each_value do |v|
        return if image.width <= v.dig(:max, :width).to_i ||
                  image.height <= v.dig(:max, :height).to_i ||
                  (v.dig(:min, :width).present? && image.width >= v.dig(:min, :width).to_i) ||
                  (v.dig(:min, :height).present? && image.height >= v.dig(:min, :height).to_i)
      end

      if image.width >= image.height
        if image.width < options.dig(:landscape, :min, :width).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.landscape.min.width',
            substitutions: { data: options.dig(:landscape, :min, :width).to_i }
          }
        end
        if image.height < options.dig(:landscape, :min, :height).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.landscape.min.height',
            substitutions: { data: options.dig(:landscape, :min, :height).to_i }
          }
        end
        if options.dig(:landscape, :max, :width).present? && image.width > options.dig(:landscape, :max, :width).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.landscape.max.width',
            substitutions: { data: options.dig(:landscape, :max, :width).to_i }
          }
        end
        if options.dig(:landscape, :max, :height).present? && image.height > options.dig(:landscape, :max, :height).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.landscape.max.height',
            substitutions: { data: options.dig(:landscape, :max, :height).to_i }
          }
        end
      else
        if image.width < options.dig(:portrait, :min, :width).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.portrait.min.width',
            substitutions: { data: options.dig(:portrait, :min, :width).to_i }
          }
        end
        if image.height < options.dig(:portrait, :min, :height).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.portrait.min.height',
            substitutions: { data: options.dig(:portrait, :min, :height).to_i }
          }
        end
        if options.dig(:portrait, :max, :width).present? && image.width > options.dig(:portrait, :max, :width).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.portrait.max.width',
            substitutions: { data: options.dig(:portrait, :max, :width).to_i }
          }
        end
        if options.dig(:portrait, :max, :height).present? && image.height > options.dig(:portrait, :max, :height).to_i
          errors.add :file, {
            path: 'uploader.validation.dimensions.portrait.max.height',
            substitutions: { data: options.dig(:portrait, :max, :height).to_i }
          }
        end
      end
    end

    def duplicate_candidates
      @duplicate_candidates ||= begin
        return [] if duplicate_check&.dig('phash').blank?

        DataCycleCore::Image
          .joins(thing: :translations)
          .where("things.schema -> 'features' -> 'duplicate_candidate' ->> 'method' = ?", 'bild_duplicate')
          .where("duplicate_check IS NOT NULL AND duplicate_check ->> 'phash' IS NOT NULL AND duplicate_check ->> 'phash' != '0' AND phash_hamming(?, duplicate_check ->> 'phash') <= ? AND assets.id != ?", duplicate_check['phash']&.to_s, 6, id)
          .map(&:thing)
          .flatten
      end
    end

    def duplicate_candidates_with_score
      @duplicate_candidates_with_score ||= begin
        return [] if duplicate_check&.dig('phash').blank?

        DataCycleCore::Image
          .joins(thing: :translations)
          .select("(100 - (100 * phash_hamming('#{duplicate_check['phash']}', assets.duplicate_check ->> 'phash') / 255)) AS score, assets.*")
          .where("things.schema -> 'features' -> 'duplicate_candidate' ->> 'method' = ?", 'bild_duplicate')
          .where("assets.duplicate_check IS NOT NULL AND assets.duplicate_check ->> 'phash' IS NOT NULL AND assets.duplicate_check ->> 'phash' != '0' AND phash_hamming(?, assets.duplicate_check ->> 'phash') <= ? AND assets.id != ?", duplicate_check['phash']&.to_s, 6, id)
          .map { |d| { content: d.thing, method: 'phash', score: d.try(:score) } }
      end
    end

    private

    def metadata_from_blob
      if attachment_changes['file'].attachable.is_a?(::Hash) && attachment_changes['file'].attachable.dig(:io).present?
        # import from local disc
        path_to_tempfile = attachment_changes['file'].attachable.dig(:io).path
      else
        path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
      end

      image = ::MiniMagick::Image.new(path_to_tempfile)
      colorspace = { ImColorSpace: image.data.dig('colorspace') }
      exif_data = MiniExiftool.new(path_to_tempfile, { replace_invalid_chars: true })
      exif_data
        .to_hash
        .transform_values { |value| value.is_a?(String) ? value.delete("\u0000") : value }
        .merge!(colorspace)
    end

    def set_duplicate_hash
      self.process_file_upload = true
      file.recreate_versions!(:thumb_preview)
      save!(validate: false)
    end
  end
end
