# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class AssetSerializer
      class << self
        def mime_type(content)
          content.asset.file.content_type
        end

        def file_extension(mime_type)
          Rack::Mime::MIME_TYPES.invert[mime_type]
        end

        def serialize(content)
          content.asset.file.path
        end
      end
    end
  end
end
