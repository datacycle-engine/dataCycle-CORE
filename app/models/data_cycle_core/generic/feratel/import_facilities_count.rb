# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportFacilitiesCount
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications_frame(
            utility_object,
            options.dig(:import, :tree_label) || 'Feratel - Ausstattungsmerkmale',
            method(:classification_processing).to_proc,
            options
          )
        end

        def self.classification_processing(mongo_item, logging, utility_object, locale, tree_name, options)
          item_count = 0
          external_source_id = utility_object.external_source.id
          load_root_classifications(mongo_item, locale, options).to_a.each do |classification_data|
            next if options[:min_count].present? && item_count < options[:min_count]
            item_count += 1
            parent_classification_data = load_parent_classification_alias(classification_data['_id'], external_source_id, options)
            next if parent_classification_data.blank?

            classification_data['values'].each do |amount|
              child_classification_data = {
                external_key: "#{classification_data['_id']} - #{amount}",
                name: "#{parent_classification_data.name} - #{amount}",
                tree_name: tree_name
              }

              DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                utility_object: utility_object,
                classification_data: child_classification_data,
                parent_classification_alias: parent_classification_data
              )

              logging.item_processed(
                child_classification_data[:name],
                child_classification_data[:external_key],
                item_count,
                nil
              )
            end
            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          logging.phase_finished("#{options.dig(:importer_name)}(#{options.dig(:phase_name)}) #{locale}", item_count)
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          mongo_item.collection.aggregate(
            [
              { '$unwind': "$dump.#{locale}.Facilities.Facility" },
              { '$addFields': { 'facility_id': "$dump.#{locale}.Facilities.Facility.Id", 'value': "$dump.#{locale}.Facilities.Facility.Value" } },
              { '$group': { _id: { facility_id: '$facility_id', value: '$value' } } },
              { '$group': { _id: '$_id.facility_id', values: { '$addToSet': '$_id.value' } } }
            ]
          )
        end

        def self.load_parent_classification_alias(external_key, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: external_key
            )
            .try(:primary_classification_alias)
        end
      end
    end
  end
end
