# frozen_string_literal: true

module DataCycleCore
  class SrtUploader < CommonUploader
    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym }, :format) || ['srt']
    end
  end
end
