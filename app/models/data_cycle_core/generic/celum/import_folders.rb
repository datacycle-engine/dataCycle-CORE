# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module ImportFolders
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Celum - Folders',
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, _locale, _options)
          mongo_item.where('dump.de.root.#cdata-section': 'true')
        end

        def self.load_child_classifications(mongo_item, parent_category_data, _locale)
          mongo_item.where('dump.de.parentFolder.#cdata-section': parent_category_data.dig('id', '#cdata-section'))
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: "Folder:#{raw_data.dig('parentFolder', '#cdata-section')}"
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: "Folder:#{raw_data.dig('id', '#cdata-section')}",
            name: raw_data.dig('name', '#cdata-section')
          }
        end
      end
    end
  end
end
