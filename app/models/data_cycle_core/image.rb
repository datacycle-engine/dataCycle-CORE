# frozen_string_literal: true

require 'mini_magick'
require 'image_processing/mini_magick'
require 'phash/image'
require 'mini_exiftool_vendored'

module DataCycleCore
  class Image < Asset
    has_one_attached :file
    after_create_commit :set_duplicate_hash

    cattr_reader :versions, default: { original: {}, thumb_preview: {}, web: {}, default: {} }
    attr_accessor :remote_file_url
    before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }

    WEB_SAVE_MIME_TYPES = [
      'image/gif',
      'image/png',
      'image/jpeg',
      'image/webp'
    ].freeze

    DEFAULT_MIME_TYPE = 'image/jpeg'

    def custom_validators
      DataCycleCore.uploader_validations[self.class.name.demodulize.underscore]&.except(:format)&.presence&.each do |validator, options|
        try("#{validator}_validation", options)
      end
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:image, :format).presence || ['jpg', 'jpeg', 'gif', 'png', 'bmp', 'tif', 'tiff', 'webp']
    end

    def self.content_type_white_list
      super.map { |type| type.gsub('application', 'image') }
    end

    def resolution_validation(options)
      return unless file&.attached?

      if attachment_changes.present?
        if attachment_changes['file']&.attachable.is_a?(::Hash) && attachment_changes['file']&.attachable&.dig(:io).present?
          # import from local disc
          path_to_tempfile = attachment_changes['file'].attachable[:io].path
        else
          path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
        end
      else
        path_to_tempfile = file.service.path_for(file.key)
      end

      image = ::MiniMagick::Image.new(path_to_tempfile)

      resolution = image.width * image.height

      if options.key?(:max) && resolution > options[:max].to_i
        errors.add(:file,
                   :invalid,
                   path: 'uploader.validation.resolution.max',
                   substitutions: { data: { method: 'number_with_delimiter', value: options[:max].to_i } })
      elsif options.key?(:min) && resolution < options[:min].to_i
        errors.add(:file,
                   :invalid,
                   path: 'uploader.validation.resolution.min',
                   substitutions: { data: { method: 'number_with_delimiter', value: options[:minmax].to_i } })
      end
    rescue StandardError
      errors.add(:file, :invalid, path: 'uploader.validation.invalid_file')
    end

    def dimensions_validation(options)
      return if options.dig(:exclude, :format)&.include?(file.filename&.to_s&.split('.')&.last) || file&.attached? == false

      if attachment_changes.present?
        if attachment_changes['file']&.attachable.is_a?(::Hash) && attachment_changes['file']&.attachable&.dig(:io).present?
          # import from local disc
          path_to_tempfile = attachment_changes['file'].attachable[:io].path
        else
          path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
        end
      else
        path_to_tempfile = file.service.path_for(file.key)
      end
      image = ::MiniMagick::Image.new(path_to_tempfile)

      options.except(:exclude, :landscape, :portrait).presence&.each_value do |v|
        return if image.width <= v.dig(:max, :width).to_i ||
                  image.height <= v.dig(:max, :height).to_i ||
                  (v.dig(:min, :width).present? && image.width >= v.dig(:min, :width).to_i) ||
                  (v.dig(:min, :height).present? && image.height >= v.dig(:min, :height).to_i)
      end

      if image.width >= image.height
        if image.width < options.dig(:landscape, :min, :width).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.landscape.min.width',
                     substitutions: { data: options.dig(:landscape, :min, :width).to_i }
        end
        if image.height < options.dig(:landscape, :min, :height).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.landscape.min.height',
                     substitutions: { data: options.dig(:landscape, :min, :height).to_i }
        end
        if options.dig(:landscape, :max, :width).present? && image.width > options.dig(:landscape, :max, :width).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.landscape.max.width',
                     substitutions: { data: options.dig(:landscape, :max, :width).to_i }
        end
        if options.dig(:landscape, :max, :height).present? && image.height > options.dig(:landscape, :max, :height).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.landscape.max.height',
                     substitutions: { data: options.dig(:landscape, :max, :height).to_i }
        end
      else
        if image.width < options.dig(:portrait, :min, :width).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.portrait.min.width',
                     substitutions: { data: options.dig(:portrait, :min, :width).to_i }
        end
        if image.height < options.dig(:portrait, :min, :height).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.portrait.min.height',
                     substitutions: { data: options.dig(:portrait, :min, :height).to_i }
        end
        if options.dig(:portrait, :max, :width).present? && image.width > options.dig(:portrait, :max, :width).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.portrait.max.width',
                     substitutions: { data: options.dig(:portrait, :max, :width).to_i }
        end
        if options.dig(:portrait, :max, :height).present? && image.height > options.dig(:portrait, :max, :height).to_i
          errors.add :file,
                     :invalid,
                     path: 'uploader.validation.dimensions.portrait.max.height',
                     substitutions: { data: options.dig(:portrait, :max, :height).to_i }
        end
      end
    rescue StandardError
      errors.add(:file, :invalid, path: 'uploader.validation.invalid_file')
    end

    def duplicate_candidates
      @duplicate_candidates ||= if duplicate_check&.dig('phash').blank?
                                  []
                                else
                                  DataCycleCore::Image
                                    .joins(thing: [:translations, :thing_template])
                                    .where("thing_templates.schema -> 'features' -> 'duplicate_candidate' ->> 'method' = ?", 'bild_duplicate')
                                    .where("duplicate_check IS NOT NULL AND duplicate_check ->> 'phash' IS NOT NULL AND duplicate_check ->> 'phash' != '0' AND phash_hamming(?, duplicate_check ->> 'phash') <= ? AND assets.id != ?", duplicate_check['phash']&.to_s, 6, id)
                                    .select('DISTINCT ON ("things"."id") "assets".*')
                                    .flat_map(&:thing)
                                end
    end

    def duplicate_candidates_with_score
      @duplicate_candidates_with_score ||= if duplicate_check&.dig('phash').blank?
                                             []
                                           else
                                             DataCycleCore::Image
                                               .joins(thing: [:thing_template])
                                               .select("(100 - (100 * phash_hamming('#{duplicate_check['phash']}', assets.duplicate_check ->> 'phash') / 255)) AS score, asset_contents.thing_id AS thing_id")
                                               .where("thing_templates.schema -> 'features' -> 'duplicate_candidate' ->> 'method' = ?", 'bild_duplicate')
                                               .where("assets.duplicate_check IS NOT NULL AND assets.duplicate_check ->> 'phash' IS NOT NULL AND assets.duplicate_check ->> 'phash' != '0' AND phash_hamming(?, assets.duplicate_check ->> 'phash') <= ? AND assets.id != ?", duplicate_check['phash']&.to_s, 6, id)
                                               .map { |d| { thing_duplicate_id: d.thing_id, method: 'phash', score: d.score } }
                                           end
    end

    def thumb_preview(transformation = {})
      return unless file&.attached?

      file.variant(resize_to_fit: [300, 300], colourspace: 'srgb', format: format_for_transformation(transformation['format'])).processed
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'asset_version_generation_failed.datacycle', {
        exception: e,
        asset: self,
        version: 'thumb_preview'
      }
      nil
    end

    def web(transformation = {})
      return unless file&.attached?

      file.variant(resize_to_limit: [2048, 2048], format: format_for_transformation(transformation['format'])).processed
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'asset_version_generation_failed.datacycle', {
        exception: e,
        asset: self,
        version: 'web'
      }
      nil
    end

    def default(transformation = {})
      return unless file&.attached?

      file.variant(format: format_for_transformation(transformation['format'])).processed
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'asset_version_generation_failed.datacycle', {
        exception: e,
        asset: self,
        version: 'default'
      }
      nil
    end

    def dynamic(transformation = {})
      return unless file&.attached?

      if transformation['width'].present? || transformation['height'].present?
        file.variant(resize_to_fit: [transformation['width']&.to_i || nil, transformation['height']&.to_i || nil], format: format_for_transformation(transformation['format'])).processed
      else
        file.variant(format: format_for_transformation(transformation['format'])).processed
      end
    rescue StandardError => e
      ActiveSupport::Notifications.instrument 'asset_version_generation_failed.datacycle', {
        exception: e,
        asset: self,
        version: 'dynamic'
      }
      nil
    end

    private

    def format_for_transformation(format = nil)
      return MiniMime.lookup_by_extension(format)&.extension if format.present? && WEB_SAVE_MIME_TYPES.include?(MiniMime.lookup_by_extension(format)&.content_type)
      return MiniMime.lookup_by_content_type(content_type)&.extension if WEB_SAVE_MIME_TYPES.include?(MiniMime.lookup_by_content_type(content_type)&.content_type)
      MiniMime.lookup_by_content_type(DEFAULT_MIME_TYPE)&.extension
    end

    def metadata_from_blob
      if attachment_changes['file'].attachable.is_a?(::Hash) && attachment_changes['file'].attachable[:io].present?
        # import from local disc
        tempfile = attachment_changes['file'].attachable[:io]
      else
        tempfile = attachment_changes['file'].attachable
      end

      image_path = tempfile.is_a?(::StringIO) ? tempfile.try(:base_uri) : tempfile.path

      raise ActiveStorage::FileNotFoundError, 'Image path not found' if image_path.nil?

      image = ::MiniMagick::Image.new(image_path, tempfile)
      exif_data = MiniExiftool.new(tempfile, { replace_invalid_chars: 'true' })
      exif_data = exif_data
        .to_hash
        .transform_values { |value| value.is_a?(String) ? value.delete("\u0000") : value }
      exif_data['ImColorSpace'] = image.colorspace.to_s.gsub(/.*class|alpha/i, '').strip if image.path.present?

      exif_data
    rescue MiniMagick::Error
      {}
    ensure
      tempfile.try(:rewind)
    end

    def set_duplicate_hash
      return if duplicate_check&.dig('phash').present? && duplicate_check&.dig('phash')&.positive?

      key = thumb_preview({ 'format' => 'jpeg' })&.key

      return if key.blank?

      update_column(:duplicate_check, { phash: Phash::Image.new(file.service.path_for(key)).try(:compute_phash).try(:data) })
    end
  end
end
