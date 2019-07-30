# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class XmlSerializer
      class << self
        def mime_type(_content)
          'application/xml'
        end

        def file_extension(_mime_type)
          '.xml'
        end

        def serialize(content)
          DataCycleCore::Xml::V1::ContentsController.render(
            assigns: { content: content, language: 'de', include_parameters: [], mode_parameters: [] },
            template: 'data_cycle_core/xml/v1/contents/show',
            layout: false
          )
        end

        def serialize_watchlist(watch_list)
          DataCycleCore::Xml::V1::WatchListsController.render(
            assigns: { watch_list: watch_list, language: 'de', include_parameters: [], mode_parameters: [] },
            template: 'data_cycle_core/xml/v1/watch_lists/show',
            layout: false
          )
        end
      end
    end
  end
end
