# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class Pdf < Asset
    if DataCycleCore.experimental_features.dig('active_storage', 'enabled')
      has_one_attached :file
    else
      mount_uploader :file, PdfUploader
      process_in_background :file
      validates_integrity_of :file
      after_destroy :remove_directory
      delegate :versions, to: :file
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:pdf, :format).presence || ['pdf']
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
      if attachment_changes['file'].attachable.is_a?(::Hash) && attachment_changes['file'].attachable.dig(:io).present?
        # import from local disc
        path_to_tempfile = attachment_changes['file'].attachable.dig(:io).path
      else
        path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
      end

      reader = PDF::Reader.new(path_to_tempfile)
      return nil if reader.blank?

      content_text = ''
      content_text = reader.try(:pages)&.map { |page| page.try(:text)&.delete("\u0000") }&.join(' ') unless DataCycleCore.features.dig(:cancel_pdf_full_text_search, :enabled) == true

      {
        info: convert_info(reader.info),
        pdf_version: reader.pdf_version,
        metadata: reader.metadata,
        content: content_text,
        page_count: reader.page_count
      }
    rescue PDF::Reader::MalformedPDFError, ArgumentError, NoMethodError
      nil
    end

    def convert_info(info_hash)
      info_hash
        &.map { |key, value|
          {
            key =>
              if value.is_a?(::String)
                value
                  .encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
                  .delete("\u0000")
              else
                value
              end
          }
        }
        &.reduce({}) { |aggregate, item| aggregate.merge(item) }
    end
  end
end
