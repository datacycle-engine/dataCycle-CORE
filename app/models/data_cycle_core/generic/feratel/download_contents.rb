# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module DownloadContents
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
          data['Id']
        end

        def self.data_name(data)
          Array.wrap(data.dig('Details', 'Names', 'Translation')).first.try(:[], 'text')
        end

        def self.modified(data)
          [
            data,
            data.dig('Facilities'),
            data.dig('Addresses', 'Address'),
            data.dig('Documents', 'Document'),
            data.dig('Descriptions', 'Description'),
            data.dig('Links', 'Link'),
            data.dig('Products', 'Product'),
            data.dig('Products', 'Product', 'Descriptions', 'Description'),
            data.dig('CustomAttributes'),
            data.dig('Services', 'Service'),
            data.dig('Services', 'Service', 'Facility'),
            data.dig('Services', 'Service', 'Descriptions', 'Description'),
            data.dig('Services', 'Service', 'Products', 'Product'),
            data.dig('Services', 'Service', 'Products', 'Product', 'Descriptions', 'Description'),
            data.dig('AdditionalServices', 'AdditionalService'),
            data.dig('AdditionalServices', 'AdditionalService', 'Facilities'),
            data.dig('AdditionalServices', 'AdditionalService', 'Descriptions', 'Description'),
            data.dig('AdditionalServices', 'AdditionalService', 'Products', 'Product'),
            data.dig('AdditionalServices', 'AdditionalService', 'Products', 'Product', 'Descriptions', 'Description')
          ].compact
            .map { |i| Array.wrap(i) }
            .inject(&:+)
            .map { |i| i.dig('ChangeDate').in_time_zone }
            .max
        end
      end
    end
  end
end
