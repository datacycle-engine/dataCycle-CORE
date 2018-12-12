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
      begin
        self.metadata = file.metadata.to_utf8 if file.respond_to?(:metadata) && file.metadata.try(:to_utf8)&.to_json.present?
      rescue JSON::GeneratorError
        self.metadata = nil
      end
      self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
    end
  end
end
