# frozen_string_literal: true

module DataCycleCore
  class TextFile < DataCycleCore::Asset
    has_many :data_links, dependent: :nullify, foreign_key: 'asset_id', inverse_of: :text_file
    if DataCycleCore.experimental_features.dig('active_storage', 'enabled')
      has_one_attached :file
    else
      mount_uploader :file, TextFileUploader
      process_in_background :file
      validates_integrity_of :file
      after_destroy :remove_directory
      delegate :versions, to: :file
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:text_file, :format).presence || ['pdf']
    end

    def update_asset_attributes
      return if file.blank?
      if self.class.active_storage_activated?
        self.content_type = file.blob.content_type
        self.file_size = file.blob.byte_size
        self.name ||= file.blob.filename
        begin
          self.metadata = metadata_from_blob
        rescue JSON::GeneratorError
          self.metadata = nil
        end
        self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
      else
        self.content_type = file.file.content_type
        self.file_size = file.file.size
        self.name ||= file.file.filename
        begin
          self.metadata = file.metadata&.to_utf8 if file.respond_to?(:metadata) && file.metadata.try(:to_utf8)&.to_json.present?
        rescue JSON::GeneratorError
          self.metadata = nil
        end
      end
      self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
    end

    private

    def metadata_from_blob
      nil
    end
  end
end
