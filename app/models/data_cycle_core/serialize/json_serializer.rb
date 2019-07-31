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

        def serialize_watch_list(watch_list)
          pagination_contents = watch_list.watch_list_data_hashes.order(created_at: :desc).page(1).per(watch_list.watch_list_data_hashes.count)
          DataCycleCore::Api::V3::WatchListsController.render(
            assigns: { contents: pagination_contents, watch_list: watch_list, language: 'de', include_parameters: [], mode_parameters: [], api_version: 3 },
            template: 'data_cycle_core/api/v3/watch_lists/show',
            layout: false
          )
        end

        def serialize_stored_filter(stored_filter)
          contents = stored_filter.apply
          pagination_contents = contents.page(1).per(contents.count)
          DataCycleCore::Api::V3::ContentsController.render(
            assigns: { contents: pagination_contents, language: 'de', include_parameters: [], mode_parameters: [], api_version: 3 },
            template: 'data_cycle_core/api/v3/contents/index',
            layout: false
          )
        end
      end
    end
  end
end
