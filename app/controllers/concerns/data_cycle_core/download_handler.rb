# frozen_string_literal: true

module DataCycleCore
  module DownloadHandler
    extend ActiveSupport::Concern

    def download_content(content, serialize_format, languages, version = nil, transformation = nil)
      serializer = serializer_for_content(content, serialize_format)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serializer
      download_generic(content: content, serializer: serializer, languages: languages, version: version, serialize_method: serializer_method_for_content(content), transformation: transformation)
    end

    def download_collection(object, items, serialize_format, languages, version = nil)
      languages ||= [I18n.locale]
      download_dir = Rails.root.join('public', 'downloads')
      Dir.mkdir(download_dir) unless File.exist?(download_dir)
      cleanup_files(download_dir)

      zipfile_name = "#{object.name.parameterize(separator: '_')}-#{Time.now.to_i}.zip"
      zipfile_fullname = File.join(download_dir, zipfile_name)

      unless File.exist?(zipfile_fullname)
        Zip::File.open(zipfile_fullname, Zip::File::CREATE) do |zipfile|
          items.each do |content|
            languages.each do |language|
              next unless content.translated_locales.include?(language.to_sym)
              serialize_format.each do |format|
                serializer = serializer_for_content(content, format)

                next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)

                collection = serializer.serialize_thing(content, language, version.is_a?(Hash) ? (version.dig(content.id) || 'original') : version)
                raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)

                serialized_content = collection.first
                raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

                next unless serialized_content

                file_extension = serialized_content.file_extension

                file_name = serializer.file_name(content, language, version)
                file_name += "_#{SecureRandom.uuid}" if zipfile.find_entry("#{file_name}#{file_extension}")
                file_name += file_extension

                download_file = create_download_file(serializer, serialized_content, content, file_name)
                zipfile.add(file_name, download_file)
              end
            end
          end
        end
      end

      object.activities.create(user: current_user, activity_type: 'download', data: { collection_items: items.map(&:id) })

      send_file zipfile_fullname, filename: zipfile_name, disposition: 'attachment', type: 'application/zip'
    end

    def download_indesign_collection(object, items, serialize_format, languages, serialize_method = :serialize_thing, version = nil)
      languages ||= [I18n.locale]
      download_dir = Rails.root.join('public', 'downloads')
      Dir.mkdir(download_dir) unless File.exist?(download_dir)
      cleanup_files(download_dir)

      zipfile_name = "#{object.name.parameterize(separator: '_')}-#{Time.now.to_i}.zip"
      zipfile_fullname = File.join(download_dir, zipfile_name)

      assets = items.select { |item| item.try(:template_name) == 'Bild' }
      indesign_items = items.reject { |item| item.try(:template_name) == 'Bild' }
      unless File.exist?(zipfile_fullname)
        Zip::File.open(zipfile_fullname, Zip::File::CREATE) do |zipfile|
          indesign_items.each do |content|
            languages.each do |language|
              serializer = ('DataCycleCore::Serialize::Serializer::' + serialize_format.to_s.classify).constantize

              next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)

              collection = serializer.try(serialize_method, content, language, version.is_a?(Hash) ? (version.dig(content.id) || 'original') : version)
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)

              serialized_content = collection.first
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

              next unless serialized_content

              file_extension = serialized_content.file_extension

              file_name = serializer.file_name(content, language, version)
              file_name += "_#{SecureRandom.uuid}" if zipfile.find_entry("#{file_name}#{file_extension}")
              file_name += file_extension

              download_file = create_download_file(serializer, serialized_content, content, file_name)

              zipfile.add(file_name, download_file)
            end
          end
          if assets.size.positive?
            assets.each do |asset|
              serializer = serializer_for_content(asset, 'asset')
              next unless serializer

              collection = serializer.serialize_thing(asset, nil, version.is_a?(Hash) ? (version.dig(content.id) || 'original') : version)
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)

              serialized_content = collection.first
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

              next unless serialized_content

              file_name = "images/#{asset.id}#{serialized_content.file_extension}"
              download_file = create_download_file(serializer, serialized_content, asset, file_name)

              next if zipfile.find_entry(file_name)
              zipfile.add(file_name, download_file)
            end
          end
        end
      end

      object.activities.create(user: current_user, activity_type: 'download', data: { collection_items: items.map(&:id) })
      send_file zipfile_fullname, filename: zipfile_name, disposition: 'attachment', type: 'application/zip'
    end

    protected

    def download_generic(content:, serializer:, languages:, version: nil, serialize_method: :serialize_thing, transformation: nil)
      language = languages&.first&.to_sym || I18n.locale

      collection = serializer.try(serialize_method, content, language, version, transformation)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)

      serialized_content = collection.first
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

      mime_type = serialized_content.mime_type
      file_name = serializer.file_name(content, language, version) + serialized_content.file_extension

      download_file = create_download_file(serializer, serialized_content, content, file_name)
      content.activities.create(user: current_user, activity_type: 'download')
      send_file download_file, filename: file_name.to_s, disposition: 'attachment', type: mime_type
    end

    # remove all files older than 2 hours
    def cleanup_files(dir)
      max_age = 2
      pattern = '*.*'
      logger.info "DataCycleCore::DownloadHanlder: directory does not exist: #{dir}" unless File.directory?(dir)

      Dir.glob(File.join(File.expand_path(dir), pattern)).each do |file_name|
        File.delete(file_name) if ((Time.zone.now - File.ctime(file_name)) / 1.hour) > max_age
      end
    end

    def create_download_file(serializer, serialized_content, content, file_name)
      return serialized_content.data.path if serialized_content.file?

      download_dir = Rails.root.join('public', 'downloads')
      Dir.mkdir(download_dir) unless File.exist?(download_dir)
      download_file = File.join(download_dir, file_name)
      file_mode = 'wb' if serializer.respond_to?(:remote?) && serializer.remote?(content)
      File.open(File.join(download_file), file_mode || 'w') do |f|
        f.write serialized_content.data
      end
      download_file
    end

    def serializer_for_content(content, serialize_format = nil)
      return if content.blank?
      ('DataCycleCore::Serialize::Serializer::' + serialize_format.to_s.classify).constantize if DataCycleCore::Feature::Download.enabled_serializer_for_download?(content, serialize_format)
    end

    def serializer_method_for_content(content)
      "serialize_#{content.class.to_s.demodulize.underscore}".to_sym
    end
  end
end
