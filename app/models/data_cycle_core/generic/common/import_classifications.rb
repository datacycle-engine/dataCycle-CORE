# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportClassifications
        def import_classifications(
          utility_object, tree_name, load_root_classifications, load_child_classifications,
          load_parent_classification_alias, extract_data, options
        )

          raise ArgumentError('tree_name cannot be blank') if tree_name.blank?
          with_filters = options.dig(:import, :with_filters) || false

          external_source_id = utility_object.external_source.id
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

                    if with_filters
                      source_filter = options&.dig(:import, :source_filter) || {}
                      source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values }
                      source_filter = source_filter.merge({ "dump.#{locale}.deleted_at" => { '$exists' => false }, "dump.#{locale}.archived_at" => { '$exists' => false } })
                    end

                    times = [Time.current]

                    utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                      raw_classification_data_stack =
                        if with_filters
                          load_root_classifications.call(mongo_item, locale, options, source_filter).to_a
                        else
                          load_root_classifications.call(mongo_item, locale, options).to_a
                        end

                      while (raw_classification_data = raw_classification_data_stack.pop.try(:[], 'dump')&.dig(locale))
                        item_count += 1
                        next if options[:min_count].present? && item_count < options[:min_count]
                        extracted_classification_data = extract_data.call(options, raw_classification_data)
                        next if extracted_classification_data[:external_key].blank?

                        import_classification(
                          utility_object:,
                          classification_data: extracted_classification_data.merge({ tree_name: }),
                          parent_classification_alias: load_parent_classification_alias.call(raw_classification_data, external_source_id, options)
                        )

                        raw_classification_data_stack +=
                          if with_filters
                            load_child_classifications.call(mongo_item, raw_classification_data, locale, source_filter).to_a
                          else
                            load_child_classifications.call(mongo_item, raw_classification_data, locale).to_a
                          end

                        logging.item_processed(
                          extracted_classification_data[:name],
                          extracted_classification_data[:external_key],
                          item_count,
                          nil
                        )

                        if (item_count % 100).zero?
                          times << Time.current
                          logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                        end

                        break if options[:max_count] && item_count >= options[:max_count]
                      end

                      times << Time.current
                      logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                    end
                  ensure
                    logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count)
                  end
                end
              end
            end
          end
        end

        def import_classifications2(
          utility_object, tree_name, load_root_classifications, load_parent_classification_alias,
          extract_parent_data, extract_child_data, options
        )

          raise ArgumentError('tree_name cannot be blank') if tree_name.blank?

          external_source_id = utility_object.external_source.id
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

                    utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                      root_classifications = load_root_classifications.call(mongo_item, locale, options).to_a
                      root_classifications.each do |raw_classification_data|
                        item_count += 1
                        next if options[:min_count].present? && item_count < options[:min_count]
                        classification_data = raw_classification_data.try(:[], 'dump')&.dig(locale)

                        extracted_classification_data = extract_parent_data.call(options, classification_data)

                        import_classification(
                          utility_object:,
                          classification_data: extracted_classification_data.merge({ tree_name: }),
                          parent_classification_alias: nil
                        )

                        extract_child_data.call(options, classification_data).each do |child_classification_data|
                          import_classification(
                            utility_object:,
                            classification_data: child_classification_data.merge({ tree_name: }),
                            parent_classification_alias: load_parent_classification_alias.call(classification_data, external_source_id, options)
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
                    end
                  ensure
                    logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count)
                  end
                end
              end
            end
          end
        end

        def import_classifications_with_filter(
          utility_object, tree_name, load_root_classifications, load_child_classifications,
          load_parent_classification_alias, extract_data, options
        )
          options[:import] = options[:import].merge(with_filters: true) if options.dig(:import, :source_filter).present?
          import_classifications(
            utility_object, tree_name, load_root_classifications, load_child_classifications,
            load_parent_classification_alias, extract_data, options
          )
        end

        def import_classifications_frame(utility_object, tree_name, classification_processing, options)
          raise ArgumentError('tree_name cannot be blank') if tree_name.blank?

          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              importer_name = options.dig(:import, :name)
              phase_name = utility_object.source_type.collection_name
              logging.preparing_phase("#{utility_object.external_source.name} #{importer_name}")

              each_locale(utility_object.locales) do |locale|
                I18n.with_locale(locale) do
                  logging.phase_started("#{importer_name}(#{phase_name}) #{locale}")
                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    classification_processing.call(mongo_item, logging, utility_object, locale, tree_name, options.merge({ importer_name:, phase_name: }))
                  end
                end
              end
            end
          end
        end

        def import_classification(utility_object:, classification_data:, parent_classification_alias: nil)
          return nil if classification_data[:name].blank?

          external_source_id = utility_object.external_source.id
          external_source_id = nil if utility_object.options.dig('import', 'no_external_source_id')

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            if classification_data[:external_key].blank?
              classification = DataCycleCore::Classification
                .find_or_initialize_by(
                  external_source_id:,
                  name: classification_data[:name]
                )
            else
              classification = DataCycleCore::Classification
                .find_or_initialize_by(
                  external_source_id:,
                  external_key: classification_data[:external_key]
                ) do |c|
                  c.name = classification_data[:name]
                end
            end

            if classification.new_record?
              classification_alias = DataCycleCore::ClassificationAlias.create!(
                external_source_id:,
                **classification_data.slice(:name, :description, :uri, :classification_polygons_attributes, :assignable)
              )

              DataCycleCore::ClassificationGroup.create!(
                classification:,
                classification_alias:,
                external_source_id:
              )

              tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(
                external_source_id:,
                name: classification_data[:tree_name],
                external_key: classification_data[:tree_name]
              ) do |item|
                item.visibility = DataCycleCore.default_classification_visibilities
              end

              DataCycleCore::ClassificationTree.create!(
                {
                  classification_tree_label: tree_label,
                  parent_classification_alias:,
                  sub_classification_alias: classification_alias
                }
              )
            else
              primary_classification_alias = classification.primary_classification_alias

              if classification_data[:classification_polygons_attributes].present? && (polygon = primary_classification_alias.classification_polygons.first)
                classification_data[:classification_polygons_attributes].first[:id] = polygon.id
              end

              primary_classification_alias.update!(name: classification_data[:name], **classification_data.slice(:description, :uri, :classification_polygons_attributes, :assignable).compact_blank)

              classification_tree = primary_classification_alias.classification_tree

              classification_tree.parent_classification_alias = parent_classification_alias
              classification_tree.save!

              classification_alias = primary_classification_alias
            end

            classification.name = classification_alias.internal_name # have a readable classification_name (esp. for multilanguage classification_aliases)
            classification.description = classification_data[:description] if classification_data[:description].present?
            classification.uri = classification_data[:uri] if classification_data[:uri].present?
            classification.external_key = classification_data[:external_key]
            classification.save!
            classification_alias
          end
        end
      end
    end
  end
end
