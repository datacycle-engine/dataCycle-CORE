# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportAccommodationsAggregate
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.aggregate_to_collection(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locales)
          aggregation_array = []

          locales.each do |locale|
            aggregation_array.push(*get_aggregate(locale.to_s))
          end

          aggregation_array.push({ "$out": 'accommodations_aggregate' })

          mongo_item.collection.aggregate(aggregation_array, allow_disk_use: true)
        end

        def self.get_aggregate(locale)
          [
            { "$unwind": { "path": "$dump.#{locale}.Facilities.Facility" } },
            { "$lookup": { "from": 'facilities', "localField": "dump.#{locale}.Facilities.Facility.Id", "foreignField": "dump.#{locale}.Id", "as": "dump.#{locale}.JoinFacility" } },
            { "$unwind": { "path": "$dump.#{locale}.JoinFacility" } },
            { "$lookup": { "from": 'facility_groups', "localField": "dump.#{locale}.JoinFacility.dump.#{locale}.GroupID", "foreignField": "dump.#{locale}.Id", "as": "dump.#{locale}.JoinFacilityGroup" } },
            { "$unwind": { "path": "$dump.#{locale}.JoinFacilityGroup" } },
            { "$addFields": {
              "dump.#{locale}.Facilities.Facility.Name": "$dump.#{locale}.JoinFacility.dump.#{locale}.Name.Translation.text",
              "dump.#{locale}.Facilities.Facility.GroupID": "$dump.#{locale}.JoinFacility.dump.#{locale}.GroupID",
              "dump.#{locale}.Facilities.Facility.ValueType": "$dump.#{locale}.JoinFacility.dump.#{locale}.ValueType",
              "dump.#{locale}.Facilities.Facility.GroupName": "$dump.#{locale}.JoinFacilityGroup.dump.#{locale}.Name.Translation.text"
            } },
            { "$group": {
              '_id': "$dump.#{locale}.Id",
              "dump": { "$first": '$dump' },
              "facilities_#{locale}": { "$push": "$dump.#{locale}.Facilities.Facility" }
            } },
            { "$project": { "dump.#{locale}.Facilities": 0, "dump.#{locale}.JoinFacility": 0, "dump.#{locale}.JoinFacilityGroup": 0 } },
            { "$addFields": { "dump.#{locale}.Facilities.Facility": "$facilities_#{locale}" } },
            { "$project": { "facilities_#{locale}": 0 } }
          ]
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
#       "dump": { $first: "$dump" },
#       "facilities_de": {$push: "$dump.de.Facilities.Facility"}
#     }},
#     {$project: {"dump.de.Facilities": 0, "dump.de.JoinFacility": 0, "dump.de.JoinFacilityGroup": 0}},
#     {$addFields: { "dump.de.Facilities.Facility": "$facilities_de" } },
#     {$project: {"facilities_de": 0}},
#     {$unwind: {path: "$dump.en.Facilities.Facility"}},
#     {$lookup: {from: "facilities", localField: "dump.en.Facilities.Facility.Id", foreignField: "dump.en.Id", as: "dump.en.JoinFacility"}},
#     {$unwind: {path: "$dump.en.JoinFacility"}},
#     {$lookup: {from: "facility_groups", localField: "dump.en.JoinFacility.dump.en.GroupID", foreignField: "dump.en.Id", as: "dump.en.JoinFacilityGroup"}},
#     {$unwind: {path: "$dump.en.JoinFacilityGroup"}},
#     { $addFields: {
#       "dump.en.Facilities.Facility.Name": "$dump.en.JoinFacility.dump.en.Name.Translation.text",
#       "dump.en.Facilities.Facility.GroupID": "$dump.en.JoinFacility.dump.en.GroupID",
#       "dump.en.Facilities.Facility.ValueType": "$dump.en.JoinFacility.dump.en.ValueType",
#       "dump.en.Facilities.Facility.GroupName": "$dump.en.JoinFacilityGroup.dump.en.Name.Translation.text",
#     }},
#     { $group: {
#       _id: "$dump.en.Id",
#       "dump": { $first: "$dump" },
#       "facilities_en": {$push: "$dump.en.Facilities.Facility"}
#     }},
#     {$project: {"dump.en.Facilities": 0, "dump.en.JoinFacility": 0, "dump.en.JoinFacilityGroup": 0}},
#     {$addFields: { "dump.en.Facilities.Facility": "$facilities_en" } },
#     {$project: {"facilities_en": 0}},
#     {$out: "accomodation_aggregate"}
#   ],
#   {
#     allowDiskUse: true
#   }
# )
