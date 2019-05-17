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
      content = model&.things&.first

      return "#{asset_host}/assets/#{model.class.to_s.demodulize.underscore}/#{model.id}/#{version_name || 'original'}/#{File.basename(model.name.to_s, '.*').underscore_blanks}.#{file&.extension || File.extname(model.name.to_s).delete('.')}" if content.nil?

      I18n.with_locale(content.first_available_locale) do
        "#{asset_host}/assets/#{model.class.to_s.demodulize.underscore}/#{model.id}/#{version_name || 'original'}/#{(content.title.presence || File.basename(model.name.to_s, '.*')).underscore_blanks}.#{file&.extension || File.extname(model.name.to_s).delete('.')}"
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

    def self.dynamic_version(name, options = nil)
      version name do
        options.presence&.each do |p_option|
          if p_option.is_a?(Array) && method_defined?(p_option[0])
            process p_option[0].to_sym => p_option[1]
          elsif method_defined?(p_option)
            process p_option.to_sym
          end
        end

        define_method :full_filename do |for_file|
          file_ext = File.extname(for_file)
          basename = File.basename(for_file, file_ext)
          "#{version_name}_#{basename}.#{options&.select { |o| o.is_a?(Array) && o[0] == 'convert' }&.dig(0, 1) || file_ext.delete('.')}"
        end
      end
    end

    def dynamic_version(name:, options: nil, process: false, delay: false)
      version_uploader = self.class.dynamic_version(name, options)
      @versions[name] = version_uploader[:uploader]&.new(model, mounted_as)
      return if @versions[name].nil?
      @versions[name]&.retrieve_from_store!(file&.file)

      if process && !@versions[name].try(:file)&.exists?
        model.process_file_upload = true
        recreate_versions!(name)
      elsif delay && !@versions[name].try(:file)&.exists?
        model.delay(queue: 'carrierwave').dynamic_version(name, true)
      end

      self.class.versions.delete(name)
      @versions.delete(name)
    end

    def optimize
      return unless DataCycleCore::Feature::ImageOptimizer.optimize?(version_name)
      ::ImageOptim.new(DataCycleCore::Feature::ImageOptimizer.config).optimize_image!(current_path)
    end
  end
end
