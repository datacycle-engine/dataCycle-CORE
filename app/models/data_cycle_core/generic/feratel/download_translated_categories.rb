# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module DownloadTranslatedCategories
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options: options
          )
        end

        def self.data_id(data)
          data['Id'] || data['Order']
        end

        def self.data_name(data)
          Array.wrap(data.dig('Names', 'Translation')).first.try(:[], 'text')
        end
      end
    end
  end
end
