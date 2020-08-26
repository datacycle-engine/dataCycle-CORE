# frozen_string_literal: true

module DataCycleCore
  module DownloadHandler
    extend ActiveSupport::Concern

    def download_content(content, serialize_format, languages, version = nil, transformation = nil)
      serializer = serializer_for_content(content, serialize_format)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serializer
      download_generic(content: content, serializer: serializer, languages: languages, version: version, serialize_method: :serialize, transformation: transformation)
    end

    def download_watch_list(watch_list, serialize_format, languages, version = nil)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_serializer_format?('watch_list', serialize_format)
      serializer = ('DataCycleCore::Serialize::' + serialize_format.to_s.classify + 'Serializer').constantize

      download_generic(content: watch_list, serializer: serializer, languages: languages, version: version, serialize_method: :serialize_watch_list)
    end

    def download_stored_filter(stored_filter, serialize_format, languages, version = nil)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_serializer_format?('stored_filter', serialize_format)
      serializer = ('DataCycleCore::Serialize::' + serialize_format.to_s.classify + 'Serializer').constantize

      download_generic(content: stored_filter, serializer: serializer, languages: languages, version: version, serialize_method: :serialize_stored_filter)
    end

    def download_collection(collection, items, serialize_format, languages, version = nil)
      languages ||= [I18n.locale]
      download_dir = Rails.root.join('public', 'downloads')
      Dir.mkdir(download_dir) unless File.exist?(download_dir)
      cleanup_files(download_dir)

      zipfile_name = "#{collection.name.parameterize(separator: '_')}-#{Time.now.to_i}.zip"
      zipfile_fullname = File.join(download_dir, zipfile_name)

      unless File.exist?(zipfile_fullname)
        Zip::File.open(zipfile_fullname, Zip::File::CREATE) do |zipfile|
          items.each do |content|
            languages.each do |language|
              next unless content.translated_locales.include?(language.to_sym)
              serialize_format.each do |format|
                serializer = serializer_for_content(content, format)

                next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)

                serialized_content, response_mime_type = serializer.serialize(content, language, version.is_a?(Hash) ? (version.dig(content.id) || 'original') : version)

                next unless serialized_content

                mime_type = serializer.mime_type(serialized_content, content).presence || response_mime_type
                file_extension = serializer.file_extension(mime_type)

                next unless file_extension

                download_file = create_download_file(serializer, serialized_content, content, file_extension, serializer.translatable? ? language : nil)

                file_name = download_file_name(content, serializer.translatable? ? language : nil)
                file_name += "_#{SecureRandom.uuid}" if zipfile.find_entry("#{file_name}#{file_extension}")

                zipfile.add("#{file_name}#{file_extension}", download_file)
              end
            end
          end
        end
      end

      collection.activities.create(user: @current_user, activity_type: 'download', data: { collection_items: items.map(&:id) })

      send_file zipfile_fullname, filename: zipfile_name, disposition: 'attachment', type: 'application/zip'
    end

    def download_indesign_collection(collection, items, serialize_format, languages, serialize_method = :serialize, version = nil)
      languages ||= [I18n.locale]
      download_dir = Rails.root.join('public', 'downloads')
      Dir.mkdir(download_dir) unless File.exist?(download_dir)
      cleanup_files(download_dir)

      zipfile_name = "#{collection.name.parameterize(separator: '_')}-#{Time.now.to_i}.zip"
      zipfile_fullname = File.join(download_dir, zipfile_name)

      assets = items.select { |item| item.try(:template_name) == 'Bild' }
      indesign_items = items.reject { |item| item.try(:template_name) == 'Bild' }

      unless File.exist?(zipfile_fullname)
        Zip::File.open(zipfile_fullname, Zip::File::CREATE) do |zipfile|
          indesign_items.each do |content|
            languages.each do |language|
              serializer = ('DataCycleCore::Serialize::' + serialize_format.first.to_s.classify + 'Serializer').constantize
              next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)

              serialized_content, response_mime_type = serializer.try(serialize_method, content, language, version.is_a?(Hash) ? (version.dig(content.id) || 'original') : version)
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content

              next unless serialized_content

              mime_type = serializer.mime_type(serialized_content, content).presence || response_mime_type
              file_extension = serializer.file_extension(mime_type)

              next unless file_extension

              download_file = create_download_file(serializer, serialized_content, content, file_extension, serializer.translatable? ? language : nil)

              file_name = download_file_name(content, serializer.translatable? ? language : nil)
              file_name += "_#{SecureRandom.uuid}" if zipfile.find_entry("#{file_name}#{file_extension}")

              zipfile.add("#{file_name}#{file_extension}", download_file)
            end
          end
          if assets.size.positive?
            assets.each do |asset|
              serializer = serializer_for_content(asset, 'asset')
              next unless serializer
              serialized_content, response_mime_type = serializer.serialize(asset, nil, version.is_a?(Hash) ? (version.dig(asset.id) || 'original') : version)
              next unless serialized_content

              mime_type = serializer.mime_type(serialized_content, asset).presence || response_mime_type
              file_extension = serializer.file_extension(mime_type)

              next unless file_extension

              download_file = create_download_file(serializer, serialized_content, asset, file_extension, nil)

              file_name = "images/#{asset.id}#{file_extension}"

              next if zipfile.find_entry(file_name)
              zipfile.add(file_name, download_file)
            end
          end
        end
      end

      collection.activities.create(user: @current_user, activity_type: 'download', data: { collection_items: items.map(&:id) })

      send_file zipfile_fullname, filename: zipfile_name, disposition: 'attachment', type: 'application/zip'
    end

    protected

    def download_generic(content:, serializer:, languages:, version: nil, serialize_method: :serialize, transformation: nil)
      language = languages&.first&.to_sym || I18n.locale
      serialized_content, response_mime_type = serializer.try(serialize_method, content, language, version, transformation)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content

      mime_type = serializer.mime_type(serialized_content, content).presence || response_mime_type
      file_extension = serializer.file_extension(mime_type)

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless file_extension

      download_file = create_download_file(serializer, serialized_content, content, file_extension, serializer.translatable? ? language : nil)

      content.activities.create(user: @current_user, activity_type: 'download')
      send_file download_file, filename: "#{download_file_name(content, serializer.translatable? ? language : nil)}#{version.present? ? '-' + version.parameterize(separator: '_') : ''}#{file_extension}", disposition: 'attachment', type: mime_type
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

    def create_download_file(serializer, serialized_content, content, file_extension, language)
      return serialized_content.path if serialized_content.is_a?(DataCycleCore::CommonUploader)

      download_dir = Rails.root.join('public', 'downloads')
      Dir.mkdir(download_dir) unless File.exist?(download_dir)
      download_file = File.join(download_dir, download_file_name(content, language) + file_extension)
      file_mode = 'wb' if serializer.respond_to?(:remote?) && serializer.remote?(content)
      File.open(File.join(download_file), file_mode || 'w') do |f|
        f.write serialized_content
      end
      download_file
    end

    def download_file_name(content, language)
      content_title = content.try(:title) || content.try(:name)
      content_title += "_#{language}" if language.present?

      return content_title.parameterize(separator: '_').to_s if content_title.present?

      if content.try(:asset)&.file&.path&.present?
        File.basename(content.try(:asset)&.file&.path)
      else
        "#{content.template_name}_#{SecureRandom.uuid}"
      end
    end

    def serializer_for_content(content, serialize_format = nil)
      return if content.blank?
      ('DataCycleCore::Serialize::' + serialize_format.to_s.classify + 'Serializer').constantize if DataCycleCore::Feature::Serialize.allowed_serializer?(content, serialize_format)
    end
  end
end
