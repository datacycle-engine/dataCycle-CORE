# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gisolutions
      module ImportSnowResort
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.collection.aggregate(
            [
              {
                '$match': {
                  "dump.#{locale}": { '$exists': true }
                }.merge(source_filter.with_evaluated_values)
              }, {
                '$project': {
                  'name' => "$dump.#{locale}.ski_area_gisolutions",
                  "dump.#{locale}.name" => "$dump.#{locale}.ski_area_gisolutions",
                  "dump.#{locale}.id_gisolutions" => "$dump.#{locale}.id_gisolutions"
                }
              }, {
                '$group': {
                  _id: '$name',
                  'ids': { '$addToSet' => "$dump.#{locale}.id_gisolutions" }, # not used for now
                  'dump': { '$first' => '$dump' }
                }
              }, {
                '$addFields': {
                  "dump.#{locale}.ids" => '$ids' # not used for now
                }
              }
            ]
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            next if raw_data.dig('name').blank?
            DataCycleCore::Generic::Gisolutions::Processing.process_snow_resort(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :snow_resort)
            )
          end
        end
      end
    end
  end
end
