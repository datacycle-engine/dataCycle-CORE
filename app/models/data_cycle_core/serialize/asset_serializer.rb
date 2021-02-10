# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class AssetSerializer
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

        def file_extension(mime_type)
          MiniMime.lookup_by_content_type(mime_type.to_s)&.extension
        end

        def serialize(content, _language, version, transformation = nil)
          if remote?(content)
            conn = Faraday.new
            response = conn.get content.content_url
            return response.body, response.headers&.dig('content-type') if response.status == 200
          else
            return content.asset.try(version, recreate: true)&.dynamic_version(name: version, options: transformation, process: true) if version.present? && transformation.present? && (content.asset&.versions&.key?(version.to_sym) || version == 'original')
            return content.asset.try(version, recreate: true) if version.present? && content.asset&.versions&.key?(version.to_sym)
            return content.asset&.file if content.asset&.file.present?
          end
        end
      end
    end
  end
end
