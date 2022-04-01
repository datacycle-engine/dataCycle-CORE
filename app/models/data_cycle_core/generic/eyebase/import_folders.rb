# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module ImportFolders
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Eyebase - Ordnerstruktur',
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.generate_aggregation(mongo_item, parent_path, locale = 'de')
          aggregation_array = [
            { '$unwind' => "$dump.#{locale}.folder" },
            { '$project' => { 'name' => "$dump.#{locale}.folder.folder",
                              'path' => "$dump.#{locale}.folder.path",
                              'parent' => "$dump.#{locale}.folder.parent",
                              'parent_path' => "$dump.#{locale}.folder.parent_path" } }
          ]
          aggregation_array.push({ '$match' => { 'parent_path' => parent_path } })
          aggregation_array.push(
            { '$group' => { _id: '$path',
                            'name': { '$first' => '$name' },
                            'path': { '$first' => '$path' },
                            'parent' => { '$first' => '$parent' },
                            'parent_path' => { '$first' => '$parent_path' } } }
          )
          mongo_item.collection.aggregate(aggregation_array)
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          generate_aggregation(mongo_item, nil, locale).map { |i| { 'dump' => { locale => i } } }
        end

        def self.load_child_classifications(mongo_item, parent_category_data, locale)
          generate_aggregation(mongo_item, parent_category_data.dig('path'), locale).map { |i| { 'dump' => { locale => i } } }
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: "Eyebase - Ordner - #{raw_data.dig('parent_path')}"
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: "Eyebase - Ordner - #{raw_data.dig('path')}",
            name: raw_data.dig('name')
          }
        end
      end
    end
  end
end
