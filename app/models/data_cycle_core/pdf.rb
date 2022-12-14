# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class Pdf < Asset
    has_one_attached :file

    cattr_reader :versions, default: { thumb_preview: {} }
    attr_accessor :remote_file_url
    before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:pdf, :format).presence || ['pdf']
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
