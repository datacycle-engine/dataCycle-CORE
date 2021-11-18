# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportFacilityGroups
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Feratel - Merkmale',
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, options)
          source_filter = options.dig(:import, :source_filter)

          aggregation_array = [
            { '$match': source_filter },
            { '$lookup': { 'from': 'facility_groups', 'localField': "dump.#{locale}.GroupID", 'foreignField': "dump.#{locale}.Id", 'as': "dump.#{locale}.Group" } },
            { '$unwind': { 'path': "$dump.#{locale}.Group" } },
            { '$group': { '_id': "$dump.#{locale}.Group.dump.#{locale}.Id", 'dump': { '$first': "$dump.#{locale}.Group.dump" }, 'facilities': { '$push': '$$ROOT' } } },
            { '$project': { "dump.#{locale}._Type": true, "dump.#{locale}.Id": true, "dump.#{locale}.Type": true, "dump.#{locale}.Active": true, "dump.#{locale}.ChangeDate": true, "dump.#{locale}.Global": true, "dump.#{locale}.Name": true, "dump.#{locale}.Facilities": '$facilities' } }
          ]

          mongo_item.collection.aggregate(aggregation_array)
        end

        def self.load_child_classifications(_mongo_item, parent_category_data, _locale)
          parent_category_data['Facilities']
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: raw_data.dig('GroupID')
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: raw_data['Id'],
            name: raw_data.dig('Name', 'Translation', 'text')
          }
        end
      end
    end
  end
end
