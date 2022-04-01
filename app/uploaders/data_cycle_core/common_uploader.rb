# frozen_string_literal: true

module DataCycleCore
  class CommonUploader < CarrierWave::Uploader::Base
    include DataCycleCore::Engine.routes.url_helpers
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

    def url(transformation = {})
      local_asset_url(host: asset_host, klass: model.class.to_s.demodulize.underscore, id: model.id, version: (version_name || 'original'), file: "#{File.basename(model.name.to_s, '.*').underscore_blanks}.#{file&.extension || File.extname(model.name.to_s).delete('.')}", transformation: transformation)
    end

    def file_name
      @file_name ||= begin
        "#{File.basename(model.name.to_s, '.*')}.#{file&.extension || File.extname(model.name.to_s).delete('.')}"
      end
    end

    def filename
      return unless original_filename

      if model && model&.read_attribute(mounted_as).present?
        "#{File.basename(model.read_attribute(mounted_as), '.*')}.#{file.extension}"
      else
        "#{secure_token}.#{file.extension}"
      end
    end

    def secure_token
      var = :"@#{mounted_as}_secure_token"
      model.instance_variable_get(var) || model.instance_variable_set(var, SecureRandom.uuid)
    end

    def convert_format(new_format)
      if new_format.to_s == 'pdf'
        convert_to_pdf
      else
        convert(new_format)
      end
    end

    def self.dynamic_version(name, options = nil, from_version = nil)
      config = {}
      config[:from_version] = from_version.to_sym if from_version.present?

      version name.to_sym, config do
        process convert_format: options['format'] if options['format'].present?
        process resize_to_fit: [options['width'], options['height']] if options.key?('width') || options.key?('height')
        process :optimize if DataCycleCore::Feature::ImageOptimizer.enabled?
        process :content_type

        define_method :full_filename do |for_file|
          basename = File.basename(for_file, File.extname(for_file)).delete_prefix("#{from_version}_")
          file_ext = options['format'] || MiniMime.lookup_by_content_type(MiniMime.lookup_by_filename(for_file)&.content_type.to_s)&.extension

          "#{name}_#{basename}.#{file_ext}"
        end
      end
    end

    def dynamic_version(name:, options: nil, process: false)
      return if options&.values.blank?

      new_format = MiniMime.lookup_by_content_type(MiniMime.lookup_by_extension(options['format'].to_s)&.content_type.to_s)&.extension
      if new_format.present? && (
        extension_white_list.include?(new_format) ||
        DataCycleCore::Feature::Serialize.asset_versions(model.thing).dig(name)&.include?(new_format)
      ) && MiniMime.lookup_by_content_type(MiniMime.lookup_by_filename(current_path.to_s)&.content_type.to_s)&.extension != new_format
        options['format'] = new_format
      else
        options.delete('format')
      end

      version_name = "#{name}_#{options.slice('format', 'width', 'height').to_h.flatten.join('_').presence || 'dynamic'}".to_sym
      version_uploader = self.class.dynamic_version(version_name, options, (name.to_sym == :original ? nil : name))
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
      mime_type = MiniMime.lookup_by_filename(current_path.to_s)&.content_type
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
        convert.resize("#{288 * 100 / current_resolution}%")
        convert.density(288)
        convert.compress('jpeg')
        convert << current_path
        convert << thumb_path
      end
      File.rename thumb_path, current_path
    end
  end
end
