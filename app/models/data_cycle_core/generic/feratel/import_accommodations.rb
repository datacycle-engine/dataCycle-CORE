# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportAccommodations
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          aggregation_array = [
            {
              '$match': {
                "dump.#{locale}": { '$exists': 'true' }
              }.merge(source_filter.with_evaluated_values)
            },
            { '$unwind': { 'path': "$dump.#{locale}.Facilities.Facility" } },
            { '$lookup': {
              'from': 'facilities',
              'localField': "dump.#{locale}.Facilities.Facility.Id",
              'foreignField': "dump.#{locale}.Id",
              'as': "dump.#{locale}.JoinFacility"
            } },
            { '$unwind': { 'path': "$dump.#{locale}.JoinFacility" } },
            { '$lookup': {
              'from': 'facility_groups',
              'localField': "dump.#{locale}.JoinFacility.dump.#{locale}.GroupID",
              'foreignField': "dump.#{locale}.Id",
              'as': "dump.#{locale}.JoinFacilityGroup"
            } },
            { '$unwind': { 'path': "$dump.#{locale}.JoinFacilityGroup" } },
            { '$addFields': {
              "dump.#{locale}.Facilities.Facility.Name": "$dump.#{locale}.JoinFacility.dump.#{locale}.Name.Translation.text",
              "dump.#{locale}.Facilities.Facility.GroupID": "$dump.#{locale}.JoinFacility.dump.#{locale}.GroupID",
              "dump.#{locale}.Facilities.Facility.ValueType": "$dump.#{locale}.JoinFacility.dump.#{locale}.ValueType",
              "dump.#{locale}.Facilities.Facility.GroupName": "$dump.#{locale}.JoinFacilityGroup.dump.#{locale}.Name.Translation.text"
            } },
            { '$group': {
              '_id': "$dump.#{locale}.Id",
              "dump": { '$first': '$dump.de' },
              "facilities": { '$push': "$dump.#{locale}.Facilities.Facility" }
            } },
            # TODO: Better than project? $mergeObjects?
            { '$project': {
              "external_id": '$_id',
              "dump.#{locale}._Type": '$dump._Type',
              "dump.#{locale}.Id": '$dump.Id',
              "dump.#{locale}.ChangeDate": '$dump.ChangeDate',
              "dump.#{locale}.Details": '$dump.Details',
              "dump.#{locale}.Descriptions": '$dump.Descriptions',
              "dump.#{locale}.Links": '$dump.Links',
              "dump.#{locale}.Facilities.Facility": '$facilities',
              "dump.#{locale}.Facilities.ChangeDate": '$dump.Facilities.ChangeDate',
              "dump.#{locale}.Addresses": '$dump.Addresses',
              "dump.#{locale}.QualityDetails": '$dump.QualityDetails'
            } }
          ]
          # binding.pry
          mongo_item.collection.aggregate(aggregation_array, allow_disk_use: true)
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['feratel_owners'].each do |name_tag|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', name_tag).deep_symbolize_keys }
              )
            end

            DataCycleCore::Generic::Feratel::Processing.process_image(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :image)
            )

            # to include rooms, services and pricing to accommodations
            # [raw_data.dig('Services', 'Service')]&.flatten&.compact&.each do |service_data|
            #   DataCycleCore::Generic::Feratel::Processing.process_room(
            #     utility_object,
            #     service_data,
            #     options.dig(:import, :transformations, :room)
            #   )
            # end
            #
            # [raw_data.dig('AdditionalServices', 'AdditionalService')]&.flatten&.compact&.each do |service_data|
            #   DataCycleCore::Generic::Feratel::Processing.process_additional_service(
            #     utility_object,
            #     service_data,
            #     options.dig(:import, :transformations, :room)
            #   )
            # end

            DataCycleCore::Generic::Feratel::Processing.process_accommodation(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
          end
        end
      end
    end
  end
end

# mongo query:
# db.getCollection("accommodations").aggregate([
#     {$unwind: {path: "$dump.de.Facilities.Facility"}},
#     {$lookup: {from: "facilities", localField: "dump.de.Facilities.Facility.Id", foreignField: "dump.de.Id", as: "dump.de.JoinFacility"}},
#     {$unwind: {path: "$dump.de.JoinFacility"}},
#     {$lookup: {from: "facility_groups", localField: "dump.de.JoinFacility.dump.de.GroupID", foreignField: "dump.de.Id", as: "dump.de.JoinFacilityGroup"}},
#     {$unwind: {path: "$dump.de.JoinFacilityGroup"}},
#     { $addFields: {
#       "dump.de.Facilities.Facility.Name": "$dump.de.JoinFacility.dump.de.Name.Translation.text",
#       "dump.de.Facilities.Facility.GroupID": "$dump.de.JoinFacility.dump.de.GroupID",
#       "dump.de.Facilities.Facility.ValueType": "$dump.de.JoinFacility.dump.de.ValueType",
#       "dump.de.Facilities.Facility.GroupName": "$dump.de.JoinFacilityGroup.dump.de.Name.Translation.text",
#     }},
#     { $group: {
#       _id: "$dump.de.Id",
#       "dump": { $first: "$dump.de" },
#       "facilities": {$push: "$dump.de.Facilities.Facility"}
#     }},
#     //TODO: Better than project? $mergeObjects?
#     {$project: {"external_id": "$_id", "dump.de._Type": "$dump._Type", "dump.de.Id": "$dump.Id", "dump.de.ChangeDate": "$dump.ChangeDate", "dump.de.Details": "$dump.Details", "dump.de.Descriptions": "$dump.Descriptions", "dump.de.Links": "$dump.Links", "dump.de.Facilities.Facility": "$facilities", "dump.de.Facilities.ChangeDate": "$dump.Facilities.ChangeDate", "dump.de.Addresses": "$dump.Addresses", "dump.de.QualityDetails": "$dump.QualityDetails"}}
#   ],
#   {
#     allowDiskUse: true
#   }
# )
