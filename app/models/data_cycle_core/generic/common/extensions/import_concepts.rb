# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Extensions
        module ImportConcepts
          def import_concept_schemes(utility_object:, iterator:, data_processor:, external_system_processor:, options:)
            init_logging(utility_object) do |logging|
              init_mongo_db(utility_object) do
                importer_name = options.dig(:import, :name)
                phase_name = utility_object.source_type.collection_name
                logging.preparing_phase("#{utility_object.external_source.name} #{importer_name}")

                each_locale(utility_object.locales) do |locale|
                  I18n.with_locale(locale) do
                    item_count = 0

                    begin
                      logging.phase_started("#{importer_name}(#{phase_name}) #{locale}")

                      source_filter = options&.dig(:import, :source_filter) || {}
                      source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values(binding) }

                      times = [Time.current]

                      utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                        raw_data = iterator.call(mongo_item, locale, source_filter).to_a
                        concept_scheme_data = raw_data.map { |rd| data_processor.call(raw_data: rd.dump[locale], utility_object:, locale:, options:) }.compact.uniq

                        concept_scheme_data = external_system_processor.call(data_array: concept_scheme_data, options:, utility_object:)

                        upserted = concept_scheme_data.present? ? DataCycleCore::ClassificationTreeLabel.upsert_all(concept_scheme_data, unique_by: :index_ctl_on_external_source_id_and_external_key, returning: :id) : []

                        item_count += upserted.count
                        times << Time.current

                        logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                      end
                    rescue StandardError => e
                      logging.error("#{importer_name}(#{phase_name}) #{locale}", nil, nil, e.message)
                      raise
                    ensure
                      logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count)
                    end
                  end
                end
              end
            end
          end

          def import_concepts(utility_object:, iterator:, data_processor:, external_system_processor:, options:)
            init_logging(utility_object) do |logging|
              init_mongo_db(utility_object) do
                importer_name = options.dig(:import, :name)
                phase_name = utility_object.source_type.collection_name
                logging.preparing_phase("#{utility_object.external_source.name} #{importer_name}")

                each_locale(utility_object.locales) do |locale|
                  I18n.with_locale(locale) do
                    item_count = 0

                    begin
                      logging.phase_started("#{importer_name}(#{phase_name}) #{locale}")

                      source_filter = options&.dig(:import, :source_filter) || {}
                      source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values(binding) }

                      times = [Time.current]

                      utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                        raw_data = iterator.call(mongo_item, locale, source_filter).to_a
                        concepts_data = raw_data.map { |rd| data_processor.call(raw_data: rd.dump[locale], utility_object:, locale:, options:) }

                        concepts_data = external_system_processor.call(data_array: concepts_data, options:)

                        concepts_data.each do |concept_scheme, concepts|
                          next logging.error("#{importer_name}(#{phase_name}) #{locale}", nil, nil, 'ConceptScheme missing!') if concept_scheme.nil?

                          upserted = concept_scheme.upsert_all_external_classifications(concepts)
                          item_count += upserted.count
                        end

                        times << Time.current

                        logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                      end
                    rescue StandardError => e
                      logging.error("#{importer_name}(#{phase_name}) #{locale}", nil, nil, e.message)
                      raise
                    ensure
                      logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count)
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
