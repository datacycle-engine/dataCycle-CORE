# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class Base
        class << self
          def translatable?
            raise NotImplementedError
          end

          def mime_type
            raise NotImplementedError
          end

          def serialize_thing(content:, language:, **options)
            raise NotImplementedError
          end

          def serialize_watch_list(content:, language:, **options)
            raise NotImplementedError
          end

          def serialize_stored_filter(content:, language:, **options)
            raise NotImplementedError
          end

          def file_name(content:, **options)
            content_title = content.try(:title) || content.try(:name)

            if content_title.present?
              content_title = "#{try(:file_name_prefix, content)}#{content_title}" if respond_to?(:file_name_prefix)
              content_title += "_#{options[:language]}" if translatable? && options.dig(:language).present?
              content_title += "-#{options[:version]}" if options.dig(:version).present?
              return content_title.parameterize(separator: '_').to_s
            end

            if content.try(:asset)&.file&.path&.present?
              File.basename(content.try(:asset)&.file&.path)
            else
              "#{content.template_name}_#{SecureRandom.uuid}"
            end
          end

          def serializable?(content)
            DataCycleCore::Feature::Serialize.available_serializer?(content, name.demodulize.underscore)
          end
        end
      end
    end
  end
end
