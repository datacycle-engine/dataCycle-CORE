# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Extensions
        module ImportConcepts
          def import_concept_schemes(utility_object:, iterator:, data_processor:, external_system_processor:, options:)
            init_logging(utility_object) do |logging|
              init_mongo_db(utility_object) do
                each_locale(utility_object.locales) do |locale|
                  I18n.with_locale(locale) do
                    item_count = 0
                    step_label = utility_object.step_label(options.merge({ locales: [locale] }))

                    begin
                      logging.phase_started(step_label)
                      times = [Time.current]

                      utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                        filter_object = Import::FilterObject.new(options&.dig(:import, :source_filter), locale, mongo_item, binding)
                        raw_data = filtered_items(iterator, locale, filter_object).to_a
                        concept_scheme_data = raw_data.filter_map { |rd| data_processor.call(raw_data: rd.dump[locale], utility_object:, locale:, options:) }.uniq

                        concept_scheme_data = external_system_processor.call(data_array: concept_scheme_data, options:, utility_object:)

                        upserted = concept_scheme_data.present? ? DataCycleCore::ClassificationTreeLabel.upsert_all(concept_scheme_data, unique_by: :index_ctl_on_external_source_id_and_external_key, returning: :id) : []

                        item_count += upserted.count
                        times << Time.current
                        logging.phase_partial(step_label, item_count, times)
                      end

                      logging.phase_finished(step_label, item_count)
                    rescue StandardError => e
                      logging.phase_failed(e, utility_object.external_source, step_label, 'import_failed.datacycle')
                    end
                  end
                end
              end
            end
          end

          def import_concepts(utility_object:, iterator:, data_processor:, data_transformer:, data_mapping_processor:, data_geom_processor:, options:)
            init_logging(utility_object) do |logging|
              init_mongo_db(utility_object) do
                each_locale(utility_object.locales) do |locale|
                  I18n.with_locale(locale) do
                    item_count = 0
                    mapping_count = 0
                    step_label = utility_object.step_label(options.merge({ locales: [locale] }))

                    begin
                      logging.phase_started(step_label)
                      times = [Time.current]

                      utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                        filter_object = Import::FilterObject.new(options&.dig(:import, :source_filter), locale, mongo_item, binding)
                        raw_data = filtered_items(iterator, locale, filter_object).to_a
                        concepts_data = raw_data.map { |rd| data_processor.call(raw_data: rd.dump[locale], utility_object:, locale:, options:) }.compact_blank

                        transformed_concepts = data_transformer.call(data_array: concepts_data, options:)
                        transformed_concepts.each do |concept_scheme, concepts|
                          next logging.error(step_label, nil, nil, 'ConceptScheme missing!') if concept_scheme.nil?

                          upserted = concept_scheme.upsert_all_external_classifications(concepts)
                          tree_item_count = upserted.count
                          times << Time.current

                          logging.phase_partial(step_label, tree_item_count, times, concept_scheme.name)

                          item_count += tree_item_count
                        rescue StandardError => e
                          logging.error_instrument(
                            exception: e,
                            external_system: utility_object.external_source,
                            step_label:,
                            channel: 'object_import_failed.datacycle',
                            namespace: 'importer',
                            item_id: "#{concept_scheme.name} (#{concept_scheme.external_key})"
                          )
                          item_count
                        end

                        additional_text = []

                        # import new mappings
                        concept_mappings = data_mapping_processor.call(data_array: concepts_data, utility_object:, options:)
                        mapped = DataCycleCore::ConceptLink.insert_all(concept_mappings, unique_by: :index_concept_links_on_parent_id_and_child_id, returning: :id)
                        mapping_count += mapped.count
                        additional_text << "#{mapping_count} new mappings" if mapping_count.positive?

                        # import new geoms
                        concept_geoms = data_geom_processor.call(data_array: concepts_data, utility_object:, options:)
                        geoms_count = DataCycleCore::ClassificationPolygon.upsert_all_geoms(concept_geoms)
                        additional_text << "#{geoms_count} new geoms" if geoms_count.positive?

                        times << Time.current
                        logging.phase_partial(step_label, item_count, times, additional_text.join(', '))
                      end

                      logging.phase_finished(step_label, item_count, times.last - times.first)
                    rescue StandardError => e
                      logging.phase_failed(e, utility_object.external_source, step_label, 'import_failed.datacycle')
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
