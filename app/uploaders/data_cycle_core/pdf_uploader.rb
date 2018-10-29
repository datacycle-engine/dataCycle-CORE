# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class PdfUploader < CommonUploader
    include CarrierWave::MiniMagick

    # Create different versions of your uploaded files:
    version :thumb_preview do
      process convert: 'png'
      # process :colorspace => 'rgb'
      # process resize_to_fit: [800, 300]

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end

    def extension_white_list
      ['pdf']
    end

    def metadata
      reader = PDF::Reader.new(current_path)
      return nil if reader.blank?
      {
        info: reader.info,
        pdf_version: reader.pdf_version,
        metadata: reader.metadata,
        page_count: reader.page_count
      }
    end
  end
end
