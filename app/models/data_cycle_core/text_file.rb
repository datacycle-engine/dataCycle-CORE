# frozen_string_literal: true

module DataCycleCore
  class TextFile < DataCycleCore::Asset
    mount_uploader :file, TextUploader
    process_in_background :file

    validate :file_size_validation

    private

    def file_size_validation
      errors[:file] << I18n.t(:file_too_large, scope: [:validation, :errors], max: ApplicationController.helpers.number_to_human_size(5.megabytes, locale: DataCycleCore.ui_language), locale: DataCycleCore.ui_language) if file.size > 5.megabytes
    end
  end
end
