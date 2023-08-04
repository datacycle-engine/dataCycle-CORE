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

          def mime_type(serialized_content:, content:)
            (
              serialized_content.try(:content_type) ||
                serialized_content.try(:variation)&.try(:content_type) ||
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

          def serialize_thing(content:, language:, **options)
            content = Array.wrap(content)

            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              content
                .select { |item| serializable?(item) }
                .map { |item| serialize(item, language, (options.dig(:version) || options.dig(:versions, item.id)), options.dig(:transformation)) }
            )
          end

          def serializable?(content)
            DataCycleCore::Feature::Serialize.available_serializer?(content, name.demodulize.underscore) && content.asset_property_names.present?
          end

          private

          def serialize(content, language, version = nil, transformation = nil)
            version ||= 'original'
            data = nil
            mime_type = nil
            remote = false
            if DataCycleCore::Feature::ImageProxy.enabled? && DataCycleCore::Feature::ImageProxy.supported_content_type?(content) && version != 'original'

              proxy_format = transformation&.dig('format')

              case version
              when 'thumb_preview'
                proxy_variant = 'thumb'
              else
                proxy_variant = version
              end

              if proxy_format.present?
                processing_instructions = DataCycleCore::Feature::ImageProxy.config.dig(proxy_variant, 'processing')
                processing_instructions['format'] = proxy_format

                data_url = DataCycleCore::Feature::ImageProxy.process_image(
                  content:,
                  variant: 'dynamic',
                  image_processing: processing_instructions
                )
              else
                data_url = DataCycleCore::Feature::ImageProxy.process_image(
                  content:,
                  variant: proxy_variant
                )
              end

              remote = true
            elsif remote?(content)
              data_url = content.content_url
              remote = true
            else
              data = create_asset(content, version, transformation)
              mime_type = mime_type(serialized_content: data, content:)
            end

            DataCycleCore::Serialize::SerializedData::Content.new(
              data:,
              mime_type:,
              file_name: file_name(content:, language:, version: content.asset&.versions&.key?(version.to_sym) ? version : 'original'),
              is_remote: remote,
              id: content.id,
              data_url:
            )
          end

          def create_asset(content, version, transformation)
            return content.asset.try(:dynamic, transformation&.to_h) if content.asset.respond_to?(:dynamic) && transformation.present?
            return content.asset.try(version) if content.asset.respond_to?(version)
            content.asset.file.presence
          end
        end
      end
    end
  end
end
