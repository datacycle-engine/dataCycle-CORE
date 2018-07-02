# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Download
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: ->(data) { data['item_id'] },
            data_name: ->(data) { data['titel'] },
            options: options
          )
        end
      end
    end
  end
end
