# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class License < Base
        class << self
          def translatable?
            true
          end

          def mime_type
            'text/plain'
          end

          def serialize_thing(content:, language:, **options)
            content = Array.wrap(content)
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                copyright_file(content, language, file_names_by_content_id(options.dig(:serialized_collections) || [])),
                introduction_file(language)
              ].compact_blank
            )
          end

          private

          def copyright_file(content, language, content_ids_with_filenames)
            data = []
            content.each do |item|
              license_string = item.try(:copyright_notice_override).presence || item.try(:copyright_notice_computed).presence || item.name.to_s
              (content_ids_with_filenames.dig(item.id) || []).each do |file_name|
                data << [file_name, license_string].join(': ')
              end
            end
            DataCycleCore::Serialize::SerializedData::Content.new(
              data: data.join("\r\n"),
              mime_type:,
              file_name: I18n.t('feature.serialize.license.copyright.file_name', default: 'copyright', locale: language),
              id: SecureRandom.uuid
            )
          end

          def terms_of_service_file(language = 'de')
            tos_file = DataCycleCore.features.dig('download', 'downloader', 'archive', 'zip', 'terms_of_use', language) ||
                       DataCycleCore.features.dig('download', 'downloader', 'archive', 'zip', 'terms_of_use', 'de')
            return nil if tos_file.blank?
            file_path = Rails.root.join('app', 'assets', 'downloader', 'archive', 'zip', 'terms_of_use', tos_file)
            file_path = Rails.root.join('app', 'assets', 'downloader', 'archive', 'zip', 'terms_of_use', DataCycleCore.features.dig('download', 'terms_of_use_file', 'de')) unless File.exist?(file_path)
            return nil unless File.exist?(file_path)

            file = begin
              File.binread(file_path)
            rescue StandardError
              nil
            end
            return nil if file.nil?

            file_name = I18n.t('feature.serialize.license.terms_of_use', default: 'Nutzungsbedingungen', locale: language) + File.extname(file_path)
            DataCycleCore::Serialize::SerializedData::Content.new(
              data: file,
              mime_type: nil,
              file_name:,
              id: SecureRandom.uuid
            )
          end

          def introduction_file(language)
            terms_of_service_file(language) ||
              DataCycleCore::Serialize::SerializedData::Content.new(
                data: I18n.t('feature.serialize.license.introduction.text', default: 'Your text goes here', locale: language),
                mime_type:,
                file_name: I18n.t('feature.serialize.license.introduction.file_name', default: 'introduction', locale: language),
                id: SecureRandom.uuid
              )
          end

          def file_names_by_content_id(serialized_collections)
            content_ids_with_filenames = {}
            serialized_collections.each do |serialized_collection|
              serialized_collection.each do |serialized_content|
                content_ids_with_filenames[serialized_content.id] = [] if content_ids_with_filenames[serialized_content.id].blank?
                content_ids_with_filenames[serialized_content.id] << serialized_content.file_name_with_extension
              end
            end
            content_ids_with_filenames
          end
        end
      end
    end
  end
end
