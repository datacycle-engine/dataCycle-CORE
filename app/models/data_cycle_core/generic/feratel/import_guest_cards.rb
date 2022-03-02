# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportGuestCards
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications_frame(
            utility_object,
            options.dig(:import, :tree_label) || 'Feratel - GuestCards',
            method(:classification_processing).to_proc,
            options
          )
        end

        def self.classification_processing(mongo_item, logging, utility_object, locale, tree_name, options)
          item_count = 0

          root_classifications = DataCycleCore::Generic::Common::ImportTags.load_root_classifications(mongo_item, locale, options).to_a
          root_classifications.each do |raw_classification_data|
            item_count += 1
            next if options[:min_count].present? && item_count < options[:min_count]
            classification_data = raw_classification_data.try(:[], 'dump')&.dig(locale)

            extracted_classification_data = DataCycleCore::Generic::Common::ImportTags.extract_data(options, classification_data)

            DataCycleCore::Generic::Common::ImportFunctions.import_classification(
              utility_object: utility_object,
              classification_data: extracted_classification_data.merge({ tree_name: tree_name }),
              parent_classification_alias: nil
            )

            external_source_id = utility_object.external_source.id
            parent_classification_data = load_parent_classification_alias(classification_data['id'], external_source_id, options)

            usage_types.each do |usage_type|
              child_classification_data = {
                external_key: "#{classification_data['id']} - #{usage_type}",
                name: usage_type.to_s,
                tree_name: tree_name
              }

              DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                utility_object: utility_object,
                classification_data: child_classification_data,
                parent_classification_alias: parent_classification_data
              )
            end

            logging.item_processed(
              extracted_classification_data[:name],
              extracted_classification_data[:external_key],
              item_count,
              nil
            )

            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          logging.phase_finished("#{options.dig(:importer_name)}(#{options.dig(:phase_name)}) #{locale}", item_count)
        end

        def self.load_parent_classification_alias(external_key, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: external_key
            )
            .try(:primary_classification_alias)
        end

        def self.usage_types
          [
            'Included',
            'Discounted',
            'SpecialService'
          ]
        end
      end
    end
  end
end
