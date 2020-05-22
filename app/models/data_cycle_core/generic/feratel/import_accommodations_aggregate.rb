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

        def self.load_contents(mongo_item, _locale)
          aggregation_array = [
            { "$unwind": { 'path': '$dump.de.Facilities.Facility' } },
            { "$lookup": { 'from': 'facilities', 'localField': 'dump.de.Facilities.Facility.Id', 'foreignField': 'dump.de.Id', 'as': 'dump.de.JoinFacility' } },
            { "$unwind": { 'path': '$dump.de.JoinFacility' } },
            { "$lookup": { 'from': 'facility_groups', 'localField': 'dump.de.JoinFacility.dump.de.GroupID', 'foreignField': 'dump.de.Id', 'as': 'dump.de.JoinFacilityGroup' } },
            { "$unwind": { 'path': '$dump.de.JoinFacilityGroup' } },
            { "$addFields": {
              "dump.de.Facilities.Facility.Name": '$dump.de.JoinFacility.dump.de.Name.Translation.text',
              "dump.de.Facilities.Facility.GroupID": '$dump.de.JoinFacility.dump.de.GroupID',
              "dump.de.Facilities.Facility.ValueType": '$dump.de.JoinFacility.dump.de.ValueType',
              "dump.de.Facilities.Facility.GroupName": '$dump.de.JoinFacilityGroup.dump.de.Name.Translation.text'
            } },
            { "$group": {
              '_id': '$dump.de.Id',
              "dump": { "$first": '$dump' },
              "facilities_de": { "$push": '$dump.de.Facilities.Facility' }
            } },
            { "$unwind": { 'path': '$dump.en.Facilities.Facility' } },
            { "$lookup": { 'from': 'facilities', 'localField': 'dump.en.Facilities.Facility.Id', 'foreignField': 'dump.en.Id', 'as': 'dump.en.JoinFacility' } },
            { "$unwind": { 'path': '$dump.en.JoinFacility' } },
            { "$lookup": { 'from': 'facility_groups', 'localField': 'dump.en.JoinFacility.dump.en.GroupID', 'foreignField': 'dump.en.Id', 'as': 'dump.en.JoinFacilityGroup' } },
            { "$unwind": { 'path': '$dump.en.JoinFacilityGroup' } },
            { "$addFields": {
              "dump.en.Facilities.Facility.Name": '$dump.en.JoinFacility.dump.en.Name.Translation.text',
              "dump.en.Facilities.Facility.GroupID": '$dump.en.JoinFacility.dump.en.GroupID',
              "dump.en.Facilities.Facility.ValueType": '$dump.en.JoinFacility.dump.en.ValueType',
              "dump.en.Facilities.Facility.GroupName": '$dump.en.JoinFacilityGroup.dump.en.Name.Translation.text'
            } },
            { "$group": {
              '_id': '$dump.en.Id',
              "dump": { "$first": '$dump' },
              "facilities_de": { "$first": '$facilities_de' },
              "facilities_en": { "$push": '$dump.en.Facilities.Facility' }
            } },
            { "$project": { "dump.de.Facilities": 0, "dump.de.JoinFacility": 0, "dump.de.JoinFacilityGroup": 0 } },
            { "$addFields": { "dump.de.Facilities.Facility": '$facilities_de' } },
            { "$project": { "facilities_de": 0 } },
            { "$project": { "dump.en.Facilities": 0, "dump.en.JoinFacility": 0, "dump.en.JoinFacilityGroup": 0 } },
            { "$addFields": { "dump.en.Facilities.Facility": '$facilities_en' } },
            { "$project": { "facilities_en": 0 } },
            { "$out": 'accommodations_aggregate' }
          ]

          mongo_item.collection.aggregate(aggregation_array, allow_disk_use: true)
        end

        # TODO: locale dependent aggregation array
        # join, group depending on locale array, project
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
#       "facilities_de": { $first: "$facilities_de" },
#       "facilities_en": {$push: "$dump.en.Facilities.Facility"}
#     }},
#     {$project: {"dump.de.Facilities": 0, "dump.de.JoinFacility": 0, "dump.de.JoinFacilityGroup": 0}},
#     {$addFields: { "dump.de.Facilities.Facility": "$facilities_de" } },
#     {$project: {"facilities_de": 0}},
#     {$project: {"dump.en.Facilities": 0, "dump.en.JoinFacility": 0, "dump.en.JoinFacilityGroup": 0}},
#     {$addFields: { "dump.en.Facilities.Facility": "$facilities_en" } },
#     {$project: {"facilities_en": 0}},
#     {$out: "accomodation_aggregate"}
#   ],
#   {
#     allowDiskUse: true
#   }
# )
