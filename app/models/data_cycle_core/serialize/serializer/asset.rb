# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class Asset < Base
        class << self
          def translatable?
            false
          end

          def remote?(content)
            content.asset&.file.blank? && content.content_url.present?
          end

          def mime_type(serialized_content, content)
            (
              serialized_content.try(:content_type) ||
                MiniMime.lookup_by_extension(content.try(:file_format)&.downcase.to_s)&.content_type ||
                content.try(:file_format) ||
                MiniMime.lookup_by_extension(File.extname(content.content_url).delete_prefix('.'))&.content_type ||
                MiniMime.lookup_by_filename(File.basename(content.content_url))&.content_type
            )
          end

          # legacy method for indesign downloader
          def file_extension(mime_type)
            ext = MiniMime.lookup_by_content_type(mime_type.to_s)&.extension
            return if ext.blank?

            ".#{ext}"
          end

          def serialize_thing(content, _language, version, transformation = nil)
            data = nil
            mime_type = nil
            if remote?(content)
              conn = Faraday.new do |f|
                f.request :retry, {
                  max: 2
                }
                f.response :follow_redirects
              end
              response = conn.get content.content_url
              if response.success?
                data = response.body
                mime_type = response.headers&.dig('content-type')
              end
            else
              data = create_asset(content, version, transformation)
              mime_type = mime_type(data, content)
            end
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data: data,
                  mime_type: mime_type
                )
              ]
            )
          end

          def create_asset(content, version, transformation)
            return content.asset.try(version, recreate: true)&.dynamic_version(name: version, options: transformation, process: true) if version.present? && transformation.present? && (content.asset&.versions&.key?(version.to_sym) || version == 'original')
            return content.asset.try(version, recreate: true) if version.present? && content.asset&.versions&.key?(version.to_sym)
            content.asset&.file.presence
          end
        end
      end
    end
  end
end
