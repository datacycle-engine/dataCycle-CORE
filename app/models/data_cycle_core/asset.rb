module DataCycleCore
  class Asset < ActiveRecord::Base

    # acts_as_paranoid

    # belongs_to :medium

    def set_content_type
      self.content_type = self.file.sanitized_file.content_type
      self
    end

    def set_file_size
      self.file_size = self.file.size
      self
    end

  end
end
