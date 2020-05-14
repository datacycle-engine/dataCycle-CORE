# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportInfrastructureClassifications
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications_frame(
            utility_object,
            options.dig(:import, :tree_label) || 'Feratel - Infrastrukturklassifizierungen',
            method(:classification_processing).to_proc,
            options
          )
        end

        def self.classification_processing(mongo_item, logging, utility_object, locale, tree_name, options)
          item_count = 0
          load_root_classifications(mongo_item, locale, options).to_a.each do |root_item|
            next if options[:min_count].present? && item_count < options[:min_count]
            item_count += 1
            root_data = root_item.dig('dump', locale.to_s)

            root_classification_data = load_root_data(root_data, tree_name)
            root_classification_alias = DataCycleCore::Generic::Common::ImportFunctions.import_classification(
              utility_object: utility_object,
              classification_data: root_classification_data,
              parent_classification_alias: nil
            )

            ['Rubrik1', 'Rubrik2'].each do |rubrik|
              item_count += 1
              second_level_data = load_second_level_data(root_data, rubrik, tree_name)
              second_classification_alias = DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                utility_object: utility_object,
                classification_data: second_level_data,
                parent_classification_alias: root_classification_alias
              )
              root_data.dig(rubrik).each do |topic_data|
                next if topic_data.nil?
                item_count += 1
                topic = topic_data.dig('dump', locale.to_s)
                child_data = load_child_data(topic, tree_name)
                DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                  utility_object: utility_object,
                  classification_data: child_data,
                  parent_classification_alias: second_classification_alias
                )
              end
            end
            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          logging.phase_finished("#{options.dig(:importer_name)}(#{options.dig(:phase_name)}) #{locale}", item_count)
        end

        def self.load_root_classifications(mongo_item, locale, options)
          source_filter = options.dig(:import, :source_filter) || {}

          aggregation_array = [
            {
              '$match': {
                'dump.de.Active': 'true'
              }.merge(source_filter)
            },
            {
              '$lookup': {
                'from': 'infrastructure_types',
                'localField': "dump.#{locale}.Type",
                'foreignField': "dump.#{locale}.Type",
                'as': "dump.#{locale}.Group"
              }
            },
            {
              '$unwind': {
                'path': "$dump.#{locale}.Group"
              }
            },
            {
              '$group': {
                '_id': "$dump.#{locale}.Group.dump.#{locale}.Type",
                'dump': { '$first': "$dump.#{locale}.Group.dump" },
                'Rubrik1': {
                  '$push': { '$cond': [{ '$eq': ['$dump.de.SubType', '1'] }, '$$ROOT', nil] }
                },
                'Rubrik2': {
                  '$push': { '$cond': [{ '$eq': ['$dump.de.SubType', '2'] }, '$$ROOT', nil] }
                }
              }
            },
            {
              '$project': {
                "dump.#{locale}._Type": true,
                "dump.#{locale}.Id": true,
                "dump.#{locale}.Type": true,
                "dump.#{locale}.Active": true,
                "dump.#{locale}.ChangeDate": true,
                "dump.#{locale}.Global": true,
                "dump.#{locale}.Name": true,
                "dump.#{locale}.Rubrik1": '$Rubrik1',
                "dump.#{locale}.Rubrik2": '$Rubrik2'
              }
            }
          ]

          mongo_item.collection.aggregate(aggregation_array)
        end

        def self.load_root_data(raw_data, tree_name)
          {
            external_key: "#{raw_data.dig('_Type')} |> #{raw_data.dig('Type')}",
            name: raw_data.dig('Name', 'Translation', 'text'),
            tree_name: tree_name
          }
        end

        def self.load_second_level_data(raw_data, rubrik, tree_name)
          {
            external_key: "#{raw_data.dig('_Type')} |> #{raw_data.dig('Type')} |> #{rubrik}",
            name: "#{raw_data.dig('Name', 'Translation', 'text')} |> #{rubrik}",
            tree_name: tree_name
          }
        end

        def self.load_child_data(raw_data, tree_name)
          {
            external_key: raw_data.dig('Id'),
            name: raw_data.dig('Name', 'Translation', 'text'),
            tree_name: tree_name
          }
        end
      end
    end
  end
end

# mongo query:
#
# db.getCollection('infrastructure_topics').aggregate([
#     {$match: {'dump.de.Active': 'true'}},
#     {$lookup: {from: 'infrastructure_types', localField: 'dump.de.Type', foreignField: 'dump.de.Type', as: 'dump.de.Group'}},
#     {$unwind: {path: '$dump.de.Group'}},
#     {$group: {
#         _id: "$dump.de.Group.dump.de.Type",
#         'dump': { '$first': '$dump.de.Group.dump'},
#         'Rubrik1': {
#             '$push': {
#                 $cond: [ { $eq: [ '$dump.de.SubType', '1'] }, '$$ROOT', null ]
#             }
#         },
#         'Rubrik2': {
#             '$push': {
#                 $cond: [ { $eq: [ '$dump.de.SubType', '2'] }, '$$ROOT', null ]
#             }
#         }
#     }},
#     {
#       '$project': {
#          "dump.de._Type": true,
#          "dump.de.Id": true,
#          "dump.de.Type": true,
#          "dump.de.Active": true,
#          "dump.de.ChangeDate": true,
#          "dump.de.Global": true,
#          "dump.de.Name": true,
#          "dump.de.Rubrik1": '$Rubrik1',
#          "dump.de.Rubrik2": '$Rubrik2'
#    }
# }
# ])
