# frozen_string_literal: true

module DataCycleCore
  class Image < Asset
    mount_uploader :file, ImageUploader
    process_in_background :file
    validates_integrity_of :file
    after_destroy :remove_directory
    delegate :versions, to: :file

    after_create_commit :set_duplicate_hash, if: proc { |image| image.persisted? && file.enable_processing && !image.file.thumb_preview&.file&.exists? }

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

    def set_duplicate_hash
      self.process_file_upload = true
      file.recreate_versions!(:thumb_preview)
      save!(validate: false)
    end
  end
end
