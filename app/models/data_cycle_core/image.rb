# frozen_string_literal: true

module DataCycleCore
  class Image < Asset
    mount_uploader :file, ImageUploader
    process_in_background :file

    def dimensions_validation(options)
      return if options.dig(:exclude, :format)&.include?(file.filename&.split('.')&.last) || file&.file.nil?

      image = ::MiniMagick::Image.new(file.file.path)

      options.except(:exclude, :landscape, :portrait).presence&.each_value do |v|
        return if image.width <= v.dig(:max, :width).to_i ||
                  image.height <= v.dig(:max, :height).to_i ||
                  (v.dig(:min, :width).present? && image.width >= v.dig(:min, :width).to_i) ||
                  (v.dig(:min, :height).present? && image.height >= v.dig(:min, :height).to_i)
      end

      if image.width >= image.height
        errors.add :file, I18n.t('uploader.validation.dimensions.landscape.min.width', data: options.dig(:landscape, :min, :width).to_i, locale: DataCycleCore.ui_language) if image.width < options.dig(:landscape, :min, :width).to_i
        errors.add :file, I18n.t('uploader.validation.dimensions.landscape.min.height', data: options.dig(:landscape, :min, :height).to_i, locale: DataCycleCore.ui_language) if image.height < options.dig(:landscape, :min, :height).to_i
        errors.add :file, I18n.t('uploader.validation.dimensions.landscape.max.width', data: options.dig(:landscape, :max, :width).to_i, locale: DataCycleCore.ui_language) if options.dig(:landscape, :max, :width).present? && image.width > options.dig(:landscape, :max, :width).to_i
        errors.add :file, I18n.t('uploader.validation.dimensions.landscape.max.height', data: options.dig(:landscape, :max, :height).to_i, locale: DataCycleCore.ui_language) if options.dig(:landscape, :max, :height).present? && image.height > options.dig(:landscape, :max, :height).to_i
      else
        errors.add :file, I18n.t('uploader.validation.dimensions.portrait.min.width', data: options.dig(:portrait, :min, :width).to_i, locale: DataCycleCore.ui_language) if image.width < options.dig(:portrait, :min, :width).to_i
        errors.add :file, I18n.t('uploader.validation.dimensions.portrait.min.height', data: options.dig(:portrait, :min, :height).to_i, locale: DataCycleCore.ui_language) if image.height < options.dig(:portrait, :min, :height).to_i
        errors.add :file, I18n.t('uploader.validation.dimensions.portrait.max.width', data: options.dig(:portrait, :max, :width).to_i, locale: DataCycleCore.ui_language) if options.dig(:portrait, :max, :width).present? && image.width > options.dig(:portrait, :max, :width).to_i
        errors.add :file, I18n.t('uploader.validation.dimensions.portrait.max.height', data: options.dig(:portrait, :max, :height).to_i, locale: DataCycleCore.ui_language) if options.dig(:portrait, :max, :height).present? && image.height > options.dig(:portrait, :max, :height).to_i
      end
    end

    def duplicate_candidates
      @duplicate_candidates ||= begin
        return [] if duplicate_check&.dig('phash').blank?

        DataCycleCore::Image.includes(:things).where.not(asset_contents: { content_data_id: nil }).where("duplicate_check IS NOT NULL AND duplicate_check ->> 'phash' IS NOT NULL AND duplicate_check ->> 'phash' != '0' AND phash_hamming(?, duplicate_check ->> 'phash') <= ? AND assets.id != ?", duplicate_check['phash']&.to_s, 6, id).map(&:things).flatten
      end
    end

    def duplicate_candidates_with_score
      @duplicate_candidates_with_score ||= begin
        return [] if duplicate_check&.dig('phash').blank?

        DataCycleCore::Image.select("(100 - (100 * phash_hamming('#{duplicate_check['phash']}', assets.duplicate_check ->> 'phash') / 255)) AS score, *").where("assets.duplicate_check IS NOT NULL AND assets.duplicate_check ->> 'phash' IS NOT NULL AND assets.duplicate_check ->> 'phash' != '0' AND phash_hamming(?, assets.duplicate_check ->> 'phash') <= ? AND assets.id != ?", duplicate_check['phash']&.to_s, 6, id).map { |d| { content: d.things&.first, method: 'phash', score: d.try(:score) } if d.things.any? }.compact
      end
    end
  end
end
