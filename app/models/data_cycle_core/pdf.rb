# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class Pdf < Asset
    after_create_commit :enqueue_extract_text_content_job, if: -> { DataCycleCore.features.dig(:cancel_pdf_full_text_search, :enabled) != true }

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
        tempfile = attachment_changes['file'].attachable.dig(:io)
      else
        tempfile = attachment_changes['file'].attachable.to_io
      end

      reader = PDF::Reader.new(tempfile)

      return nil if reader.blank?

      meta_data = {
        info: convert_info(reader.info),
        pdf_version: reader.pdf_version,
        metadata: metadata_from_reader(reader),
        content: '',
        page_count: reader.page_count
      }

      tempfile.rewind

      meta_data
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

    def enqueue_extract_text_content_job
      DataCycleCore::ExtractPdfTextContentJob.perform_later(id) if file_size&.positive?
    end

    def metadata_from_reader(reader)
      data = Nokogiri::XML(reader.metadata)
      data.remove_namespaces!

      Hash.from_xml(data.to_xml)
    rescue StandardError
      nil
    end
  end
end
