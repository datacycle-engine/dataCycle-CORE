# frozen_string_literal: true

module DataCycleCore
  class DataCycleFileUploader < CommonUploader
    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym }, :format) || []
    end
  end
end
