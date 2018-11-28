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
      ['pdf']
    end

    def convert_to_png
      pdf = MiniMagick::Image.new(current_path)
      MiniMagick::Tool::Convert.new do |convert|
        convert.density(pdf.resolution.map { |t| t * 4 }.join('x'))
        convert.trim
        convert.quality(100)
        convert.flatten
        convert.resize('25%')
        convert.colorspace('RGB')
        convert << current_path + '[0]'
        convert << Rails.root.join('public', store_path)
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
