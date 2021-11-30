# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module DeleteSnowReportsNew
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

        def self.process_content(utility_object:, raw_data:, locale:, options:) # rubocop:disable Lint/UnusedMethodArgument
          I18n.with_locale(locale) do
            raw_data.dig('snow', 'itemSnow').each do |snow_report|
              hash = TransformationFunctions.get_title_from_locale(snow_report, 'title', ->(s) { s.dig('type') }, locale)
              name = [raw_data.dig('resort', 'text'), hash['title']].join(' - ')
              DataCycleCore::Thing
                .where(external_source_id: utility_object.external_source.id, name: name)
                .order(updated_at: :desc)
                .to_a[1..-1]
                .map(&:destroy_content)
            end
          end
        end
      end
    end
  end
end
