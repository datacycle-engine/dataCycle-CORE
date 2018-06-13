# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module ImportTags
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.merge("dump.#{locale}": { '$exists' => true }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            tree_label = options.dig(:import, :transformations, :tags, :tree_label)
            keywords = raw_data.dig('attributes', 'tags') || []
            keywords.each do |item|
              DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                utility_object: utility_object,
                classification_data: { name: item, external_key: "Xamoom - tag - #{item}", tree_name: tree_label },
                parent_classification_alias: nil
              )
            end
          end
        end
      end
    end
  end
end
