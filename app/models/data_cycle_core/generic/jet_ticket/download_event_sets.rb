# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      module DownloadEventSets
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            modified: method(:modified).to_proc,
            options: options
          )
        end

        def self.data_id(data)
          data.dig('EventSetID')
        end

        def self.data_name(data)
          data.dig('Name')
        end

        def self.modified(data)
          data.dig('Modified').try(:in_time_zone)
        end
      end
    end
  end
end
