# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wikidata
      module ImportClassifications
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications_frame(
            utility_object,
            options.dig(:import, :tree_label) || 'Wikidata - Classification',
            method(:classification_processing).to_proc,
            options
          )
        end

        def self.classification_processing(mongo_item, logging, utility_object, locale, tree_name, options)
          item_count = 0
          load_root_classifications(mongo_item, locale, options).to_a.each do |raw_data|
            next if options[:min_count].present? && item_count < options[:min_count]
            item_count += 1
            classification_data = raw_data.dump.dig('de')

            item_data = {
              external_key: classification_data['external_key'],
              name: classification_data.dig('classLabel', 'value'),
              tree_name: tree_name
            }

            DataCycleCore::Generic::Common::ImportFunctions.import_classification(
              utility_object: utility_object,
              classification_data: item_data,
              parent_classification_alias: nil
            )

            logging.item_processed(item_data[:name], item_data[:external_key], item_count, nil)
            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          logging.phase_finished("#{options.dig(:importer_name)}(#{options.dig(:phase_name)}) #{locale}", item_count)
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          mongo_item.where("dump.de.external_key": { '$exists': true }, "dump.de.classLabel.xml:lang": locale)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: raw_data['external_key'],
            name: raw_data.dig('classLabel', 'value')
          }
        end
      end
    end
  end
end
