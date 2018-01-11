module DataCycleCore
  class Asset < ActiveRecord::Base
    # acts_as_paranoid

    # belongs_to :medium

    DataCycleCore.content_tables.each do |content_table|
      has_many :asset_contents, dependent: :destroy
      has_many content_table.to_sym, through: :asset_contents, source: "content_data", source_type: "DataCycleCore::#{content_table.singularize.classify}"
    end

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
