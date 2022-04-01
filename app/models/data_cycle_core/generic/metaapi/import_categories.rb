# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Metaapi
      module ImportCategories
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          mongo_item.where("dump.#{locale}.ParentID": { '$exists': false })
        end

        def self.load_child_classifications(mongo_item, parent_category_data, _locale)
          mongo_item.where('dump.de.ParentID': parent_category_data.dig('CategoryID'))
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, options)
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: "#{options.dig(:import, :external_id_prefix)}#{raw_data.dig('ParentID')}"
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(options, raw_data)
          {
            external_key: "#{options.dig(:import, :external_id_prefix)}#{raw_data.dig('CategoryID')}",
            name: raw_data.dig('Name')
          }
        end
      end
    end
  end
end
