# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module ImportAssetCollections
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Celum - Asset Collections',
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, _locale, _options)
          mongo_item.where('dump.de.root': 'true')
        end

        def self.load_child_classifications(mongo_item, parent_data, _locale)
          mongo_item.where('dump.de.parent': parent_data.dig('id'))
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: "AssetCollection:#{raw_data.dig('parent')}"
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: "AssetCollection:#{raw_data.dig('id')}",
            name: raw_data.dig('name')
          }
        end
      end
    end
  end
end
