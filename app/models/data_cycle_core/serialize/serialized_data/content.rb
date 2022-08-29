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

        # used with carrierwave
        def local_file?
          false
        end

        def active_storage?
          return false if remote? || @data.is_a?(::String)
          record_for_active_storage_file&.file&.try(:attached?)
        end

        def active_storage_file_path
          record_for_active_storage_file.file.service.path_for(@data.key)
        end

        # used for remote files and image proxy
        def remote?
          @is_remote
        end

        def record_for_active_storage_file
          return @data&.blob&.attachments&.first&.record if @data.is_a?(ActiveStorage::VariantWithRecord)
          @data&.record
        end
      end
    end
  end
end
