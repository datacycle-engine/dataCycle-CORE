# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class BaseSerializer
      class << self
        def translatable?
          raise 'NOT IMPLEMENTED'
        end

        def mime_type(_serialized_content, _content)
          raise 'NOT IMPLEMENTED'
        end

        def file_extension(_mime_type)
          raise 'NOT IMPLEMENTED'
        end

        def serialize_thing(_content, _language, _version, _transformation = nil)
          raise NotImplementedError, 'Implement this method in a child class'
        end

        def serialize_watch_list(_watch_list, _language, _version, _transformation = nil)
          raise 'NOT IMPLEMENTED'
        end

        def serialize_stored_filter(_stored_filter, _language, _version, _transformation = nil)
          raise 'NOT IMPLEMENTED'
        end
      end
    end
  end
end
