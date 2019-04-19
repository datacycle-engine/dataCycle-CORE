# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class PdfUploader < CommonUploader
    include CarrierWave::MiniMagick

    # Create different versions of your uploaded files:
    version :thumb_preview do
      process :convert_to_png
      process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.png"
      end
    end

    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore.remove('_uploader').to_sym, :format).presence || ['pdf']
    end

    def convert_to_png
      dirname = File.dirname(current_path)
      thumb_path = "#{File.join(dirname, File.basename(path, File.extname(path)))}.png"

      MiniMagick::Tool::Convert.new do |convert|
        convert.density(288)
        convert.trim
        convert.quality(100)
        convert.flatten
        convert.resize('25%')
        convert.colorspace('RGB')
        convert << "#{current_path}[0]"
        convert << thumb_path
      end
      File.rename thumb_path, current_path
    end

    def metadata
      reader = PDF::Reader.new(current_path)
      return nil if reader.blank?

      begin
        {
          info: reader.info,
          pdf_version: reader.pdf_version,
          metadata: reader.metadata,
          content: reader.pages.map(&:text).join(' '),
          page_count: reader.page_count
        }
      rescue PDF::Reader::MalformedPDFError
        nil
      end
    end
  end
end
