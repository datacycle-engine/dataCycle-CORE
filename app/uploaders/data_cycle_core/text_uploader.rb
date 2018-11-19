# frozen_string_literal: true

module DataCycleCore
  class TextUploader < CommonUploader
    def extension_white_list
      ['pdf']
    end
  end
end
