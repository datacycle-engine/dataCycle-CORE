# frozen_string_literal: true

module DataCycleCore
  class CommonUploader < CarrierWave::Uploader::Base
    # Include RMagick or MiniMagick support:
    # include CarrierWave::RMagick
    include ::CarrierWave::Backgrounder::Delay

    after :store, :meta_data

    # Choose what kind of storage to use for this uploader:
    storage :file
    # storage :fog

    # Override the directory where uploaded files will be stored.
    # This is a sensible default for uploaders that are meant to be mounted:
    def store_dir
      "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    end

    def filename
      return unless original_filename
      if model && model&.read_attribute(mounted_as).present?
        model.read_attribute(mounted_as)
      else
        "#{secure_token}.#{file.extension}"
      end
    end

    def meta_data(_file)
      model.content_type = file.content_type
      model.file_size = file.size
      model.save!
    end

    def secure_token
      var = :"@#{mounted_as}_secure_token"
      model.instance_variable_get(var) || model.instance_variable_set(var, SecureRandom.uuid)
    end
  end
end
