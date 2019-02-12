# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class PdfUploader < CommonUploader
    include CarrierWave::MiniMagick

    # Create different versions of your uploaded files:
    version :thumb_preview do
      process :convert_to_png

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.png"
      end
    end

    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore.remove('_uploader').to_sym, :format).presence || ['pdf']
    end

    def convert_to_png
      MiniMagick::Tool::Convert.new do |convert|
        convert.density(288)
        convert.trim
        convert.quality(100)
        convert.flatten
        convert.resize('25%')
        convert.colorspace('RGB')
        convert << "#{current_path}[0]"
        convert << "#{root}/#{store_path}"
      end
      FileUtils.rm_f(current_path)
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
