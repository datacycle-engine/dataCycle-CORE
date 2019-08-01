# frozen_string_literal: true

module DataCycleCore
  module DownloadHandler
    extend ActiveSupport::Concern

    def download_content(content, serialize_format)
      serializer = serializer_for_content(content, serialize_format)

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serializer

      mime_type = serializer.mime_type(content)
      file_extension = serializer.file_extension(mime_type)

      serialized_content = serializer.serialize(content)

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serialized_content

      download_file = create_download_file(serialized_content, content, file_extension)

      send_file download_file, filename: "#{download_file_name(content)}#{file_extension}", disposition: 'attachment', type: mime_type
    end

    def download_watch_list(watch_list, serialize_format)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" if !DataCycleCore::Feature::Download.collection_serializer_enabled?('watch_list') || serialize_format.blank? || DataCycleCore::Feature::Download.available_collection_serializers('watch_list').dig(serialize_format).blank?

      serializer = ('DataCycleCore::Serialize::' + serialize_format.to_s.classify + 'Serializer').constantize
      mime_type = serializer.mime_type(watch_list)
      file_extension = serializer.file_extension(mime_type)

      serialized_content = serializer.serialize_watch_list(watch_list)

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serialized_content

      download_file = create_download_file(serialized_content, watch_list, file_extension)

      send_file download_file, filename: "#{download_file_name(watch_list)}#{file_extension}", disposition: 'attachment', type: mime_type
    end

    def download_stored_filter(stored_filter, serialize_format)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" if !DataCycleCore::Feature::Download.collection_serializer_enabled?('stored_filter') || serialize_format.blank? || DataCycleCore::Feature::Download.available_collection_serializers('stored_filter').dig(serialize_format).blank?

      serializer = ('DataCycleCore::Serialize::' + serialize_format.to_s.classify + 'Serializer').constantize
      mime_type = serializer.mime_type(stored_filter)
      file_extension = serializer.file_extension(mime_type)

      serialized_content = serializer.serialize_stored_filter(stored_filter)

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serialized_content

      download_file = create_download_file(serialized_content, stored_filter, file_extension)

      send_file download_file, filename: "#{download_file_name(stored_filter)}#{file_extension}", disposition: 'attachment', type: mime_type
    end

    def download_collection(collection, items, serialize_format)
      download_dir = Rails.root.join('public', 'downloads')
      Dir.mkdir(download_dir) unless File.exist?(download_dir)
      cleanup_files(download_dir)

      zipfile_name = "#{collection.id}-#{Time.now.to_i}.zip"
      zipfile_fullname = File.join(download_dir, zipfile_name)

      unless File.exist?(zipfile_fullname)
        Zip::File.open(zipfile_fullname, Zip::File::CREATE) do |zipfile|
          items.each do |content|
            serialize_format.each do |format|
              serializer = serializer_for_content(content, format)

              next unless serializer

              mime_type = serializer.mime_type(content)
              file_extension = serializer.file_extension(mime_type)

              serialized_content = serializer.serialize(content)

              next unless serialized_content

              download_file = create_download_file(serialized_content, content, file_extension)

              file_name = download_file_name(content)
              file_name += "_#{SecureRandom.uuid}" if zipfile.find_entry("#{file_name}#{file_extension}")

              zipfile.add("#{file_name}#{file_extension}", download_file)
            end
          end
        end
      end

      send_file zipfile_fullname, filename: zipfile_name, disposition: 'attachment', type: 'application/zip'
    end

    protected

    # remove all files older than 2 hours
    def cleanup_files(dir)
      max_age = 2
      pattern = '*.*'
      logger.info "DataCycleCore::DownloadHanlder: directory does not exist: #{dir}" unless File.directory?(dir)

      Dir.glob(File.join(File.expand_path(dir), pattern)).each do |file_name|
        File.delete(file_name) if ((Time.zone.now - File.ctime(file_name)) / 1.hour) > max_age
      end
    end

    def create_download_file(serialized_content, content, file_extension)
      return serialized_content.path if serialized_content.is_a?(DataCycleCore::CommonUploader)

      download_dir = Rails.root.join('public', 'downloads')
      download_file = File.join(download_dir, download_file_name(content) + file_extension)
      File.open(File.join(download_file), 'w') do |f|
        f.write serialized_content
      end
      download_file
    end

    def download_file_name(content)
      content_title = content.try(:title) || content.try(:name)
      (content_title.blank? ? File.basename(content.try(:asset)&.file&.path) : content_title.parameterize(separator: '_')).to_s
    end

    def serializer_for_content(content, serialize_format = nil)
      return if content.blank?
      ('DataCycleCore::Serialize::' + serialize_format.to_s.classify + 'Serializer').constantize if serialize_format.present? && DataCycleCore::Feature::Serialize.allowed_serializer?(content, serialize_format)
    end
  end
end
