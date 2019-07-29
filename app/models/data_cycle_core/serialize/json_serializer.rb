# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class JsonSerializer
      class << self
        def mime_type(_content)
          'application/json'
        end

        def file_extension(_mime_type)
          '.json'
        end

        def serialize(content)
          DataCycleCore::Api::V3::ContentsController.render(
            assigns: { content: content, language: 'de', include_parameters: [], mode_parameters: [], api_version: 3 },
            template: 'data_cycle_core/api/v3/contents/show',
            layout: false
          )
        end
      end
    end
  end
end
