# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Download
        def download_content(**options)
          download_data(->(data) { data['item_id'] }, ->(data) { data['titel'] }, options)
        end
      end
    end
  end
end
