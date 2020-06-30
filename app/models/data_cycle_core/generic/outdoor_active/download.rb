# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Download
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
          data['id']
        end

        def self.data_name(data)
          data['name']
        end

        def self.modified(data)
          [
            data.dig('meta', 'date', 'lastModified'),
            Array.wrap(data.dig('images', 'image'))&.map { |item| item.dig('meta', 'date', 'lastModified').presence }&.compact&.flatten
          ].compact
            &.map { |i| Array.wrap(i) }
            &.inject(:+)
            &.map(&:in_time_zone)
            &.max
        end
      end
    end
  end
end
