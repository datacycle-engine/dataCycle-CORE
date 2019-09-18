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
              (Rack::Mime::MIME_TYPES.fetch(".#{content.try(:file_format)&.downcase}") { nil } || content.try(:file_format)) ||
              Rack::Mime::MIME_TYPES.fetch(File.extname(content.content_url)) { '' }
          )
        end

        def file_extension(mime_type)
          Rack::Mime::MIME_TYPES.invert[mime_type]
        end

        def serialize(content, _language, version, transformation = nil)
          if remote?(content)
            conn = Faraday.new
            response = conn.get content.content_url
            return response.body if response.status == 200
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
