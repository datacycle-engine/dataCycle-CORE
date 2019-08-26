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

        def mime_type(content)
          (
            content.asset&.file&.content_type ||
              (Rack::Mime::MIME_TYPES.fetch(".#{content.file_format&.downcase}") { nil } || content.file_format) ||
              Rack::Mime::MIME_TYPES.fetch(File.extname(content.content_url)) { '' }
          )
        end

        def file_extension(mime_type)
          Rack::Mime::MIME_TYPES.invert[mime_type]
        end

        def serialize(content, _language)
          return content.asset&.file if content.asset&.file.present?
          return unless remote?(content)

          conn = Faraday.new
          response = conn.get content.content_url
          return response.body if response.status == 200
        end
      end
    end
  end
end
