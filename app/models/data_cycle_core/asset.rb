# frozen_string_literal: true

module DataCycleCore
  class Asset < ApplicationRecord
    belongs_to :creator, class_name: 'DataCycleCore::User'
    mount_uploader :file, FileUploader
    before_save :update_asset_attributes
    process_in_background :file

    include AssetHelpers

    DataCycleCore.content_tables.each do |content_table|
      has_many :asset_contents, dependent: :destroy
      has_many content_table.to_sym, through: :asset_contents, source: 'content_data', source_type: "DataCycleCore::#{content_table.singularize.classify}"
    end

    def update_asset_attributes
      self.content_type = file.file.content_type
      self.file_size = file.size
      self.exif_data = file.exif_data if file.respond_to?(:exif_data)
    end
  end
end
