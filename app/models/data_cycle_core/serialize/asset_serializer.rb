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
              (MIME::Types.type_for(".#{content.try(:file_format)&.downcase}").first || content.try(:file_format)) ||
              MIME::Types.type_for(File.extname(content.content_url)).first ||
              MIME::Types.type_for(File.basename(content.content_url)).first
          )
        end

        def file_extension(mime_type)
          ".#{MIME::Types[mime_type].first&.preferred_extension}" if MIME::Types[mime_type].present?
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
