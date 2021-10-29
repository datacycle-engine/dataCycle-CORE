# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module ImportKeywords
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}.mediaassettype.text": { '$in': ['501', '503'] }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            tree_label = options.dig(:import, :transformations, :keyword, :tree_label) || 'Eyebase - Tags'
            # MO: no general Tag Importer because keywords are parsed from different attributes in the source!!
            keywords = DataCycleCore::Generic::Eyebase::Transformations.eyebase_get_keywords.call(raw_data)&.dig('keywords') || []
            keywords.each do |item|
              DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                utility_object: utility_object,
                classification_data: { name: item, external_key: "Eyebase - Tag - #{item}", tree_name: tree_label },
                parent_classification_alias: nil
              )
            end
          end
        end
      end
    end
  end
end
