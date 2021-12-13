# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module SerializedData
      class Content
        attr_accessor :data, :file, :mime_type, :file_name, :remote

        def initialize(data:, mime_type:, file_name: ,file: false, remote: false)
          @data = data
          @file = file
          @mime_type = mime_type
          @file_name = file_name
          @remote = remote
        end

        def file_extension
          ext = MiniMime.lookup_by_content_type(@mime_type.to_s)&.extension
          return if ext.blank?

          ".#{ext}"
        end

        def file?
          @file || @data.is_a?(DataCycleCore::CommonUploader)
        end
      end
    end
  end
end
