# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module SerializedData
      class Content
        attr_accessor :data, :mime_type, :file_name, :id, :is_remote

        def initialize(data:, mime_type:, file_name:, id:, is_remote: false)
          @data = data
          @mime_type = mime_type
          @file_name = file_name
          @is_remote = is_remote
          @id = id
        end

        def file_extension
          ext = MiniMime.lookup_by_content_type(@mime_type.to_s)&.extension
          return if ext.blank?

          ".#{ext}"
        end

        def file_name_with_extension
          "#{@file_name}#{file_extension}"
        end

        def local_file?
          @data.is_a?(DataCycleCore::CommonUploader)
        end

        def active_storage?
          DataCycleCore.experimental_features.dig('active_storage', 'enabled') && @data.try(:attached?) && DataCycleCore.experimental_features.dig('active_storage', 'asset_types')&.include?(@data&.record&.class&.name)
        end

        def remote?
          @is_remote
        end
      end
    end
  end
end
