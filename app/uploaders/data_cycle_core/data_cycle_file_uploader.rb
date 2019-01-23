# frozen_string_literal: true

module DataCycleCore
  class DataCycleFileUploader < CommonUploader
    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore.remove('_uploader').to_sym, :format) || []
    end
  end
end
