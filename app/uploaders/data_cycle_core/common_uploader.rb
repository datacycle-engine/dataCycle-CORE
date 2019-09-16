# frozen_string_literal: true

module DataCycleCore
  class CommonUploader < CarrierWave::Uploader::Base
    # Include RMagick or MiniMagick support:
    # include CarrierWave::RMagick
    include ::CarrierWave::Backgrounder::Delay

    # Choose what kind of storage to use for this uploader:
    storage :file
    # storage :fog

    # Override the directory where uploaded files will be stored.
    # This is a sensible default for uploaders that are meant to be mounted:
    def store_dir
      "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    end

    def url
      "#{asset_host}/assets/#{model.class.to_s.demodulize.underscore}/#{model.id}/#{version_name || 'original'}/#{File.basename(model.name.to_s, '.*').underscore_blanks}.#{file&.extension || File.extname(model.name.to_s).delete('.')}"
    end

    def file_name
      @file_name ||= begin
        "#{File.basename(model.name.to_s, '.*')}.#{file&.extension || File.extname(model.name.to_s).delete('.')}"
      end
    end

    def filename
      return unless original_filename
      if model && model&.read_attribute(mounted_as).present?
        model.read_attribute(mounted_as)
      else
        "#{secure_token}.#{file.extension}"
      end
    end

    def secure_token
      var = :"@#{mounted_as}_secure_token"
      model.instance_variable_get(var) || model.instance_variable_set(var, SecureRandom.uuid)
    end

    def self.dynamic_version(name, options = nil, from_version = nil)
      version name, from_version: from_version do
        process resize_to_limit: [options['width'], options['height']] if options.key?('width') || options.key?('height')
        if options['format'].present? && options['format'] == 'pdf'
          # process convert: options['format']
          process :convert_to_pdf
        elsif options['format'].present?
          process convert: options['format']
        end
        process :content_type

        define_method :full_filename do |for_file|
          basename = File.basename(for_file, File.extname(for_file)).delete_prefix("#{from_version}_")
          file_ext = options['format'] || MIME::Types.type_for(for_file).first.preferred_extension

          "#{name}_#{basename}.#{file_ext}"
        end
      end
    end

    def dynamic_version(name:, options: nil, process: false)
      version_name = "#{name}_#{options.slice('format', 'width', 'height').to_h.flatten.join('_')}"
      version_uploader = self.class.dynamic_version(version_name, options, (name == :original ? nil : name))
      @versions[version_name] = version_uploader[:uploader]&.new(model, mounted_as)

      return if @versions[version_name].nil?

      @versions[version_name]&.retrieve_from_store!(file&.file)

      if process && !@versions[version_name].try(:file)&.exists?
        model.process_file_upload = true
        recreate_versions!(version_name)
      end

      self.class.versions.delete(version_name)
      @versions.delete(version_name)
    end

    def content_type
      mime_type = MIME::Types.type_for(current_path).first
      file.instance_variable_set(:@content_type, mime_type.to_s)
    end

    def optimize
      return unless DataCycleCore::Feature::ImageOptimizer.optimize?(version_name)
      ::ImageOptim.new(DataCycleCore::Feature::ImageOptimizer.config).optimize_image!(current_path)
    end

    def convert_to_pdf
      dirname = File.dirname(current_path)
      thumb_path = "#{File.join(dirname, File.basename(path, File.extname(path)))}.pdf"
      current_resolution = MiniMagick::Image.open(current_path)&.resolution&.max || 72

      MiniMagick::Tool::Convert.new do |convert|
        convert.density(288)
        convert.resize("#{288 * 100 / current_resolution}%")
        convert.trim
        convert.quality(100)
        convert << current_path
        convert << thumb_path
      end
      File.rename thumb_path, current_path
    end
  end
end
