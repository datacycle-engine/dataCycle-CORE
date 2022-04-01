# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module ImportCopyrightHolder
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          aggregation = mongo_item.where(
            source_filter.with_evaluated_values.merge({
              "dump.#{locale}.mediaassettype.text": { '$in': ['501', '503'] },
              "dump.#{locale}.copyright.#cdata-section": { '$exists': true }
            })
          )
          aggregation = aggregation.project(
            'name' => "$dump.#{locale}.copyright.#cdata-section",
            "dump.#{locale}.name" => "$dump.#{locale}.copyright.#cdata-section"
          )
          aggregation = aggregation.group(
            _id: '$name',
            :dump.first => '$dump'
          ).pipeline
          mongo_item.collection.aggregate(aggregation)
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::Eyebase::Processing.process_organization(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :organization)
            )
          end
        end
      end
    end
  end
end
