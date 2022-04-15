# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Toubiz
      module ImportCategories
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications_frame(
            utility_object,
            options.dig(:import, :tree_label) || 'mein.toubiz - ',
            method(:classification_processing).to_proc,
            options
          )
        end

        def self.classification_processing(mongo_item, logging, utility_object, locale, tree_name, options)
          item_count = 0
          load_classification_trees(mongo_item, locale, options).to_a.each do |raw_data|
            locale_data = raw_data.dump.dig(locale.to_s)
            tree_name = "mein.toubiz - #{locale_data['name']}"
            first_level = locale_data.dig('childrenCategories')
            Array.wrap(first_level).each do |root_data|
              next if options[:min_count].present? && item_count < options[:min_count]
              item_count += 1

              parent_classification = DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                utility_object: utility_object,
                classification_data: extract_data(root_data, tree_name),
                parent_classification_alias: nil
              )

              Array.wrap(root_data.dig('childrenCategories')).each do |child_data|
                DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                  utility_object: utility_object,
                  classification_data: extract_data(child_data, tree_name),
                  parent_classification_alias: parent_classification
                )
              end

              logging.item_processed('mein.toubiz Categories', locale_data['id'], item_count, nil)
              break if options[:max_count] && item_count >= options[:max_count]
            end
          end
        ensure
          logging.phase_finished("#{options.dig(:importer_name)}(#{options.dig(:phase_name)}) #{locale}", item_count)
        end

        def self.load_classification_trees(mongo_item, locale, _options)
          mongo_item.where("dump.#{locale}": { '$exists': true })
        end

        def self.extract_data(data, tree)
          {
            external_key: data['id'],
            name: data['name'],
            tree_name: tree
          }
        end
      end
    end
  end
end
