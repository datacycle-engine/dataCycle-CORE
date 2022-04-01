# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportLocations
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Feratel - Orte',
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          mongo_item.where("dump.#{locale}.ParentID": '00000000-0000-0000-0000-000000000000')
        end

        def self.load_child_classifications(mongo_item, parent_category_data, locale)
          mongo_item.where("dump.#{locale}.ParentID": parent_category_data['Id'])
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(external_source_id: external_source_id, external_key: raw_data['ParentID'])
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: raw_data['Id'],
            name: raw_data['Name']
          }
        end
      end
    end
  end
end
