# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module DownloadCategories
        include DataCycleCore::Generic::Feratel::DownloadBase

        def download_content(**options)
          @range_ids = load_location_range_ids(
            options.dig(:download, :location_collection),
            options.dig(:download, :location_range_codes)
          )

          download_data(@source_type,
                        ->(data) { data['Id'] },
                        ->(data) { data['Name'] },
                        options)
        end

        def endpoint
          @end_point_object.new(credentials.symbolize_keys) do |range_code|
            @range_ids[range_code]
          end
        end
      end
    end
  end
end
