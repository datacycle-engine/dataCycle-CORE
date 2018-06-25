# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module DownloadContents
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: ->(data) { data['Id'] },
            data_name: ->(data) { [data['Details']['Names']['Translation']].flatten.first.try(:[], 'text') },
            options: options
          )
        end
      end
    end
  end
end
