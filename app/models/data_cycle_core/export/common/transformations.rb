# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      module Transformations
        def self.json_api_v2(_utility_object, data)
          DataCycleCore::Api::V2::ContentsController.render(
            assigns: { content: data, mode_parameters: [], language: 'de', include_parameters: [] },
            template: 'data_cycle_core/api/v2/contents/show',
            layout: false
          )
        end
      end
    end
  end
end
