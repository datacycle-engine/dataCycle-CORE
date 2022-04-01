# frozen_string_literal: true

module DataCycleCore
  module Generic
    module VTicket
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
          data['title']
        end

        def self.modified(data)
          [
            data.dig('meta', 'updatedAt'),
            data.dig('location', 'meta', 'updatedAt'),
            data.dig('promoter', 'meta', 'updatedAt'),
            Array.wrap(data.dig('subEvent'))&.map { |item| item.dig('meta', 'updatedAt').presence }&.compact&.flatten
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
