# frozen_string_literal: true

module DataCycleCore
  class Asset < ApplicationRecord
    attribute :type, :string, default: name
    belongs_to :creator, class_name: 'DataCycleCore::User'
    mount_uploader :file, FileUploader
    before_create :update_asset_attributes
    process_in_background :file
    validates :file, presence: true
    validates_integrity_of :file

    include AssetHelpers

    has_many :asset_contents, dependent: :destroy
    has_many :things, through: :asset_contents, source: 'content_data', source_type: 'DataCycleCore::Thing'

    def update_asset_attributes
      return if file.blank?
      self.content_type = file.file.content_type
      self.file_size = file.size
      self.name ||= file.file.filename
      self.metadata = file.metadata if file.respond_to?(:metadata)
      self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
    end
  end
end
