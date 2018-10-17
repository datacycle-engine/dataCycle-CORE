# frozen_string_literal: true

module DataCycleCore
  class PdfUploader < CommonUploader
    include CarrierWave::MiniMagick

    # Create different versions of your uploaded files:
    version :thumb_preview do
      process convert: 'jpg'
      # process :colorspace => 'rgb'
      # process resize_to_fit: [800, 300]

      def full_filename(for_file)
        basename = File.basename(for_file, File.extname(for_file))
        "#{version_name}_#{basename}.jpg"
      end
    end

    # Add a white list of extensions which are allowed to be uploaded.
    # For images you might use something like this:
    def extension_whitelist
      ['pdf']
    end

  end
end
