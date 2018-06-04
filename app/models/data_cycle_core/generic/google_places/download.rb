# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GooglePlaces
      module Download
        def download_content(**options)
          download_data(->(data) { data['place_id'] }, ->(data) { data['name'] }, options)
        end
      end
    end
  end
end
