# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module DownloadMarkUpdated
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.mark_updated(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            dependent_keys: method(:dependent_keys).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locales, source_filter)
          criteria = {
            '$or' => locales.map do |locale|
              {
                "dump.#{locale}" => { '$exists' => true },
                "dump.#{locale}.deleted_at" => { '$exists' => false },
                "dump.#{locale}.archived_at" => { '$exists' => false }
              }
            end
          }
          mongo_item.where(source_filter.with_evaluated_values.merge(criteria))
        end

        def self.dependent_keys(data)
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
            .map { |i| i.dig('Id') }
            .compact
            .sort
            .uniq
        end
      end
    end
  end
end
