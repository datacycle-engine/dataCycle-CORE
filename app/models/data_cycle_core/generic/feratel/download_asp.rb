# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module DownloadAsp
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            modified: method(:modified).to_proc,
            iterator: method(:load_contents).to_proc,
            options: options
          )
        end

        def self.data_id(data)
          data['Id']
        end

        def self.data_name(data)
          Array.wrap(data.dig('Details', 'Names', 'Translation')).first.try(:[], 'text')
        end

        def self.load_contents(mongo_item, locale, external_keys)
          mongo_item.where({ '$or' => [{ "dump.#{locale}.mark_for_update".to_sym => { '$exists' => true } }, { 'external_id' => { '$in' => external_keys } }] })
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
            Array.wrap(data.dig('Products', 'Product'))&.map { |i| Array.wrap(i.dig('Descriptions', 'Description')).presence }&.compact&.flatten,
            data.dig('CustomAttributes'),
            data.dig('Services', 'Service'),
            Array.wrap(data.dig('Services', 'Service'))&.map { |i| Array.wrap(i.dig('Facility')).presence }&.compact&.flatten,
            Array.wrap(data.dig('Services', 'Service'))&.map { |i| Array.wrap(i.dig('Descriptions', 'Description')).presence }&.compact&.flatten,
            Array.wrap(data.dig('Services', 'Service'))&.map { |i| Array.wrap(i.dig('Products', 'Product')).presence }&.compact&.flatten,
            Array.wrap(data.dig('Services', 'Service'))&.map { |i| Array.wrap(i.dig('Products', 'Product')).presence }&.compact&.flatten&.map { |i| Array.wrap(i.dig('Descriptions', 'Description')).presence }&.compact&.flatten,
            data.dig('AdditionalServices', 'AdditionalService'),
            Array.wrap(data.dig('AdditionalServices', 'AdditionalService'))&.map { |i| Array.wrap(i.dig('Facilities')).presence }&.compact&.flatten,
            Array.wrap(data.dig('AdditionalServices', 'AdditionalService'))&.map { |i| Array.wrap(i.dig('Descriptions', 'Description')).presence }&.compact&.flatten,
            Array.wrap(data.dig('AdditionalServices', 'AdditionalService'))&.map { |i| Array.wrap(i.dig('Products', 'Product')).presence }&.compact&.flatten,
            Array.wrap(data.dig('AdditionalServices', 'AdditionalService'))&.map { |i| Array.wrap(i.dig('Products', 'Product')).presence }&.compact&.flatten&.map { |i| Array.wrap(i.dig('Descriptions', 'Description')).presence }&.compact&.flatten
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
