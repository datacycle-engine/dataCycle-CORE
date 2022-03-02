# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module ImportCriterias
        def self.import_data(utility_object:, options:)
          raise 'Missing configuration attribute "tree_label"' if options.dig(:import, :tree_label).blank?

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
          mongo_item.collection.aggregate(
            [
              {
                '$project': {
                  "dump.#{locale}.grouped_search_criteria": "$dump.#{locale}.grouped_search_criteria"
                }
              }, {
                '$unwind': "$dump.#{locale}.grouped_search_criteria"
              }, {
                '$unwind': "$dump.#{locale}.grouped_search_criteria.search_criteria"
              }, {
                '$project': {
                  "dump.#{locale}.id": {
                    '$concat': [
                      Constants::SEARCH_CRITERIA_GROUP_CLASSIFICATION_PREFIX,
                      "$dump.#{locale}.grouped_search_criteria.guest_group.key"
                    ]
                  },
                  "dump.#{locale}.name": "$dump.#{locale}.grouped_search_criteria.guest_group.name_#{locale}"
                }
              }, {
                '$group': {
                  _id: "$dump.#{locale}.id",
                  dump: { '$first': '$dump' }
                }
              }
            ]
          )
        end

        def self.load_child_classifications(mongo_item, parent_category_data, locale)
          mongo_item.collection.aggregate(
            [
              {
                '$project': {
                  "dump.#{locale}.grouped_search_criteria": "$dump.#{locale}.grouped_search_criteria"
                }
              }, {
                '$unwind': "$dump.#{locale}.grouped_search_criteria"
              }, {
                '$unwind': "$dump.#{locale}.grouped_search_criteria.search_criteria"
              }, {
                '$match': {
                  "dump.#{locale}.grouped_search_criteria.guest_group.key": parent_category_data['id'].gsub(Constants::SEARCH_CRITERIA_GROUP_CLASSIFICATION_PREFIX, '')
                }
              }, {
                '$project': {
                  "dump.#{locale}.parent_id": {
                    '$concat': [
                      Constants::SEARCH_CRITERIA_GROUP_CLASSIFICATION_PREFIX,
                      "$dump.#{locale}.grouped_search_criteria.guest_group.key"
                    ]
                  },
                  "dump.#{locale}.id": {
                    '$concat': [
                      Constants::SEARCH_CRITERIA_CLASSIFICATION_PREFIX,
                      "$dump.#{locale}.grouped_search_criteria.search_criteria.id"
                    ]
                  },
                  "dump.#{locale}.name": "$dump.#{locale}.grouped_search_criteria.search_criteria.name_#{locale}"
                }
              }, {
                '$group': {
                  _id: "$dump.#{locale}.id",
                  dump: { '$first': '$dump' }
                }
              }
            ]
          )
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(external_source_id: external_source_id, external_key: raw_data['parent_id'])
            .try(:primary_classification_alias)
        end

        def self.extract_data(options, raw_data)
          external_id = raw_data['id']
          name = raw_data['name']
          {
            external_key: "#{options.dig(:import, :external_id_prefix)}#{external_id}",
            name: name
          }
        end
      end
    end
  end
end
