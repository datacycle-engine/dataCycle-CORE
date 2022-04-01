# frozen_string_literal: true

# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module ImportSubLegends
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications_frame(
            utility_object,
            options.dig(:import, :tree_label),
            method(:classification_processing).to_proc,
            options
          )
        end

        def self.classification_processing(mongo_item, logging, utility_object, locale, tree_name, options)
          item_count = 0
          external_source_id = utility_object.external_source.id
          parent_prefix = options.dig(:import, :parent_id_prefix)
          prefix = options.dig(:import, :external_id_prefix)

          load_root_classifications(mongo_item, locale, options).to_a.each do |classification_data|
            next if options[:min_count].present? && item_count < options[:min_count]
            item_count += 1
            parent_classification_data = load_parent_classification_alias(parent_prefix + classification_data['parent_id'], external_source_id, options)
            next if parent_classification_data.blank?

            child_classification_data = {
              external_key: prefix + classification_data['_id'],
              name: classification_data['name'],
              uri: classification_data['uri'],
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
            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          logging.phase_finished("#{options.dig(:importer_name)}(#{options.dig(:phase_name)}) #{locale}", item_count)
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          mongo_item.collection.aggregate(
            [
              {
                '$unwind': "$dump.#{locale}.cid"
              },
              {
                '$project': {
                  'id': "$dump.#{locale}.cid.t",
                  'name': "$dump.#{locale}.cid.c",
                  'uri': "$dump.#{locale}.cid.is",
                  'parent_id': "$dump.#{locale}.t",
                  'parent_name': "$dump.#{locale}.c"
                }
              },
              {
                '$group': {
                  _id: '$id',
                  name: { '$first': '$name' },
                  uri: { '$first': '$uri' },
                  parent_id: { '$first': '$parent_id' },
                  parent_name: { '$first': '$parent_name' }
                }
              }
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
