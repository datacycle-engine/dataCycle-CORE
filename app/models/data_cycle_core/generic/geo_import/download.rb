# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoImport
      module Download
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options: options
          )
        end

        def self.data_id(data)
          data['sde_id']
        end

        def self.data_name(data)
          data['PEVENT_BEZ']
        end
      end
    end
  end
end
