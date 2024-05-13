# frozen_string_literal: true

require 'zip_tricks'

module DataCycleCore
  module DownloadHandler
    extend ActiveSupport::Concern

    included do
      include ActionController::Live
    end

    def download_content(content, serialize_format, languages, version = nil, transformation = nil)
      serializer = serializer_for_content(content, [:content], serialize_format)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serializer
      download_generic(content:, serializer:, languages:, version:, serialize_method: serializer_method_for_content(content), transformation:)
    end

    def download_collection(object, items, serialize_format, languages, versions = nil)
      languages ||= [I18n.locale]
      zip_filenames = []
      zipfile_name = "#{object.name&.parameterize(separator: '_')}-#{Time.now.to_i}.zip"
      writer = init_stream_writer(zipfile_name)

      ZipTricks::Streamer.open(writer) do |zip|
        languages.each do |language|
          serialized_collections = []
          serialize_format.each do |format|
            serializer = serializer_for_content(object, [:archive, :zip], format)
            next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)
            collection = serializer.serialize_thing(content: items, language:, versions:, user: current_user)
            serialized_collections << collection
            raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)

            collection.each do |serialized_content|
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

              file_name = serialized_content.file_name_with_extension
              file_name = "#{file_name.split('.')[0...-1].join('.')}_#{SecureRandom.uuid}#{serialized_content.file_extension}" if zip_filenames.include?(file_name)

              zip_filenames << file_name
              zip.write_deflated_file(file_name.to_s) do |file_writer|
                serialized_content.stream_data do |chunk|
                  file_writer << chunk
                end
              end
            end
          end

          DataCycleCore::Feature::Download.mandatory_serializers_for_download(object, [:archive, :zip]).each_key do |format|
            serializer = ('DataCycleCore::Serialize::Serializer::' + format.to_s.classify).constantize
            next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)
            collection = serializer.serialize_thing(content: items, language:, serialized_collections:, user: current_user)
            raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)

            collection.each do |serialized_content|
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

              file_name = serialized_content.file_name_with_extension
              file_name = "#{file_name.split('.')[0...-1].join('.')}_#{SecureRandom.uuid}#{serialized_content.file_extension}" if zip_filenames.include?(file_name)

              zip_filenames << file_name
              zip.write_deflated_file(file_name.to_s) do |file_writer|
                serialized_content.stream_data do |chunk|
                  file_writer << chunk
                end
              end
            end
          end
        end
      end

      object.activities.create(user: current_user, activity_type: 'download', data: { collection_items: items.map(&:id), referer: request.referer})
    rescue ActionController::Live::ClientDisconnected
      # ignore client disconnections
      nil
    ensure
      response.stream.close
    end

    def download_indesign_collection(object, items, serialize_format, languages, serialize_method = :serialize_thing)
      languages ||= [I18n.locale]
      zip_filenames = []
      zipfile_name = "#{object.name&.parameterize(separator: '_')}-#{Time.now.to_i}.zip"
      writer = init_stream_writer(zipfile_name)
      ZipTricks::Streamer.open(writer) do |zip|
        languages.each do |language|
          serialize_format.each do |format|
            serializer = serializer_for_content(object, [:archive, :indesign], format)
            next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)

            collection = serializer.try(serialize_method, content: object, language:, user: current_user)
            raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)
            collection.each do |serialized_content|
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

              file_name = serialized_content.file_name_with_extension
              file_name = "#{file_name.split('.')[0...-1].join('.')}_#{SecureRandom.uuid}#{serialized_content.file_extension}" if zip_filenames.include?(file_name)

              zip_filenames << file_name
              zip.write_deflated_file(file_name.to_s) do |file_writer|
                serialized_content.stream_data do |chunk|
                  file_writer << chunk
                end
              end
            end
          end

          DataCycleCore::Feature::Download.mandatory_serializers_for_download(object, [:archive, :indesign]).each_key do |format|
            serializer = ('DataCycleCore::Serialize::Serializer::' + format.to_s.classify).constantize
            next if !serializer || (!serializer.translatable? && language.to_sym != I18n.locale)
            collection = serializer.serialize_thing(content: items, language:, user: current_user)
            raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)
            collection.each do |serialized_content|
              raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

              if format == 'asset'
                processed_file_name = "#{serialized_content.id}#{serialized_content.file_extension}"
                file_name = "images/#{processed_file_name}"
                next if zip_filenames.include?(file_name)
              else
                file_name = serialized_content.file_name_with_extension
                file_name = "#{file_name.split('.')[0...-1].join('.')}_#{SecureRandom.uuid}#{serialized_content.file_extension}" if zip_filenames.include?(file_name)
              end

              zip_filenames << file_name
              zip.write_deflated_file(file_name.to_s) do |file_writer|
                serialized_content.stream_data do |chunk|
                  file_writer << chunk
                end
              end
            end
          end
        end
      end

      object.activities.create(user: current_user, activity_type: 'download', data: { collection_items: items.map(&:id), referer: request.referer})
    rescue ActionController::Live::ClientDisconnected
      # ignore client disconnections
      nil
    ensure
      response.stream.close
    end

    def download_filtered_collection(content, query, serialize_format, languages, additional_data = {})
      serializer = serializer_for_content(content, [:content], serialize_format)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless serializer
      download_generic(content:, serializer:, languages:, version: nil, serialize_method: serializer_method_for_content(content), transformation: nil, query:, additional_data:)
    end

    protected

    def init_stream_writer(file_name)
      send_file_headers!(
        type: 'application/zip',
        disposition: 'attachment',
        filename: file_name
      )

      response.headers['Last-Modified'] = Time.now.httpdate.to_s
      response.headers['X-Accel-Buffering'] = 'no'

      ZipTricks::BlockWrite.new do |chunk|
        response.stream.write(chunk)
      end
    end

    def download_generic(content:, serializer:, languages:, version: nil, serialize_method: :serialize_thing, transformation: nil, query: nil, additional_data: {})
      language = languages&.first&.to_sym || I18n.locale

      collection = serializer.try(serialize_method, content:, language:, version:, transformation:, query:, additional_data:, user: current_user)
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless collection.is_a?(DataCycleCore::Serialize::SerializedData::ContentCollection)

      serialized_content = collection.first
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "Serialization failed for: #{serializer}" unless serialized_content.is_a?(DataCycleCore::Serialize::SerializedData::Content)

      send_file_headers!(
        type: serialized_content.mime_type,
        disposition: 'attachment',
        filename: serialized_content.file_name_with_extension
      )
      response.headers['Last-Modified'] = content.try(:cache_valid_since)&.httpdate || Time.now.httpdate
      response.headers['X-Accel-Buffering'] = 'no'

      serialized_content.stream_data do |chunk|
        response.stream.write(chunk)
      end

      content.activities.create(user: current_user, activity_type: 'download', data: additional_data.merge(
        referer: request.referer,
        origin: request.origin,
        middlewareOrigin: request.headers['X-Dc-Middleware-Origin']
      ))
    rescue ActionController::Live::ClientDisconnected
      # ignore client disconnections
      nil
    ensure
      response.stream.close
    end

    def serializer_for_content(content, scope = [:content], serialize_format = nil)
      return if content.blank?
      ('DataCycleCore::Serialize::Serializer::' + serialize_format.to_s.classify).constantize if DataCycleCore::Feature::Download.enabled_serializer_for_download?(content, scope, serialize_format)
    end

    def serializer_method_for_content(content)
      "serialize_#{content.class.to_s.demodulize.underscore}".to_sym
    end
  end
end
