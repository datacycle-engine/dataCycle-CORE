# frozen_string_literal: true

module DataCycleCore
  module Generic
    module HrsDestinationData
      module ImportClassifications
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications2(
            utility_object,
            options.dig(:import, :tree_label) || 'HRS Destination Data - Classifications',
            method(:load_root_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            method(:extract_child_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          mongo_item.collection.aggregate(
            mongo_item.where('dump.de.event.classification': { '$exists': true })
            .group(
              _id: "$dump.#{locale}.event.classification.id",
              :dump.first => '$dump'
            ).pipeline
          )
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: "HRS DD - Classification: #{raw_data.dig('event', 'classification', 'id')}"
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: "HRS DD - Classification: #{raw_data.dig('event', 'classification', 'id')}",
            name: raw_data.dig('event', 'classification', 'name')
          }
        end

        def self.extract_child_data(_options, raw_data)
          raw_data.dig('event', 'classification', 'categories')&.map { |item|
            next if item.dig('name').upcase == item.dig('name')
            {
              external_key: "HRS DD - Classification: #{raw_data.dig('event', 'classification', 'id')}_#{item.dig('id')}",
              name: item.dig('name')
            }
          }&.compact
        end
      end
    end
  end
end
