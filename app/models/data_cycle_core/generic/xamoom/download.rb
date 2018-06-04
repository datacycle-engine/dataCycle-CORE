# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module Download
        def download_content(**options)
          download_data(->(data) { data['id'] }, ->(data) { data['attributes']['name'] }, options)
        end
      end
    end
  end
end
