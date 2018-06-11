# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module DownloadRegions
        def download_content(**options)
          download_data(@source_type, ->(data) { data['id'] }, ->(data) { data['name'] }, options)
        end

        protected

        def endpoint
          @end_point_object.new(credentials.symbolize_keys)
        end
      end
    end
  end
end
