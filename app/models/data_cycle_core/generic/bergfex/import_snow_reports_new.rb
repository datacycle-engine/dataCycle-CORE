# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module ImportSnowReportsNew
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options.merge({ iterator_type: :aggregate }) # switch to aggregation
          )
        end

        def self.load_contents(mongo_item, locale, _source_filter)
          mongo_item.collection.aggregate(
            [
              {
                '$match': {
                  "dump.#{locale}": { '$exists': true },
                  "dump.#{locale}.datetime.text": { '$gt': (Time.zone.now - 3.months).to_s }
                }
              }, {
                '$sort': { "dump.#{locale}.datetime.text": -1 }
              }, {
                '$group': {
                  _id: "$dump.#{locale}.resort.id",
                  'datetime': { '$max': "$dump.#{locale}.datetime.text" },
                  'dump': { '$first': '$dump' }
                }
              }
            ]
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::Bergfex::Processing.process_snow_report_new(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :ski_resort),
              locale
            )
          end
        end
      end
    end
  end
end
