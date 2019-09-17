# frozen_string_literal: true

require 'pdf-reader'

module DataCycleCore
  class PdfUploader < CommonUploader
    include CarrierWave::MiniMagick

    # Create different versions of your uploaded files:
    version :thumb_preview do
      process convert_to_type: 'jpg'
      process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end

    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore.remove('_uploader').to_sym, :format).presence || ['pdf']
    end

    def convert_to_type(type)
      dirname = File.dirname(current_path)
      thumb_path = "#{File.join(dirname, File.basename(path, File.extname(path)))}.#{MIME::Types.type_for(type).first.preferred_extension}"

      MiniMagick::Tool::Convert.new do |convert|
        convert.density(288)
        convert.colorspace('sRGB')
        convert << "#{current_path}[0]"
        convert.resize('25%')
        convert.resize('1400x1400>')
        convert.trim
        convert.flatten
        convert.quality(100)
        convert << thumb_path
      end
      File.rename thumb_path, current_path
    end

    def convert_format(new_format)
      if MIME::Types.type_for(current_path).first == 'application/pdf'
        convert_to_type(new_format)
      else
        convert(new_format)
      end
    end

    def metadata
      reader = PDF::Reader.new(current_path)
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
        &.map do |key, value|
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
        end
        &.reduce({}) { |aggregate, item| aggregate.merge(item) }
    end
  end
end
