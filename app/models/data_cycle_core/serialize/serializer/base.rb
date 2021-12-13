# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class Base
        class << self
          def translatable?
            raise NotImplementedError, 'Implement this method in a child class'
          end

          def mime_type(_serialized_content, _content)
            raise NotImplementedError, 'Implement this method in a child class'
          end

          def serialize_thing(_content, _language, _version, _transformation = nil)
            raise NotImplementedError, 'Implement this method in a child class'
          end

          def serialize_watch_list(_watch_list, _language, _version, _transformation = nil)
            raise NotImplementedError, 'Implement this method in a child class'
          end

          def serialize_stored_filter(_stored_filter, _language, _version, _transformation = nil)
            raise NotImplementedError, 'Implement this method in a child class'
          end

          def file_name(content, language = nil, version = nil)
            content_title = content.try(:title) || content.try(:name)

            if content_title.present?
              content_title = "#{try(:file_name_prefix, content)}#{content_title}" if respond_to?(:file_name_prefix)
              content_title += "_#{language}" if translatable? && language.present?
              content_title += "-#{version.parameterize(separator: '_')}" if version.present?

              return content_title.parameterize(separator: '_').to_s
            end

            if content.try(:asset)&.file&.path&.present?
              File.basename(content.try(:asset)&.file&.path)
            else
              "#{content.template_name}_#{SecureRandom.uuid}"
            end
          end
        end
      end
    end
  end
end
