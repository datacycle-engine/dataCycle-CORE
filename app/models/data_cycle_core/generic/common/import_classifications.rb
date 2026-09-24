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
          param_types = [:key, :keyreq]

          external_source_id = utility_object.external_source.id
          init_logging(utility_object) do |logging|
            utility_object.with_mongodb do
              each_locale(utility_object.locales) do |locale|
                I18n.with_locale(locale) do
                  item_count = 0
                  step_label = utility_object.step_label(options.merge({ locales: [locale] }))
                  times = [Time.current]

                  begin
                    logging.phase_started(step_label)

                    utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                      filter_object = Import::FilterObject.new(nil, locale, mongo_item, binding)
                      if with_filters
                        filter_object.source_filter = options&.dig(:import, :source_filter)
                        filter_object = filter_object.without_deleted.without_archived
                      end

                      raw_classification_data_stack =
                        if with_filters && !filter_object?(load_root_classifications)
                          load_root_classifications.call(mongo_item, locale, options, filter_object.legacy_source_filter).to_a
                        elsif filter_object?(load_root_classifications)
                          load_root_classifications.call(filter_object:, options:).to_a
                        else
                          load_root_classifications.call(mongo_item, locale, options).to_a
                        end

                      while (raw_classification_data = raw_classification_data_stack.pop.try(:[], 'dump')&.dig(locale))
                        begin
                          item_count += 1
                          next if options[:min_count].present? && item_count < options[:min_count]

                          extracted_classification_data = if extract_data.parameters.any? { |type, name| param_types.include?(type) && name == :locale }
                                                            extract_data.call(options, raw_classification_data, locale:)
                                                          else
                                                            extract_data.call(options, raw_classification_data)
                                                          end
                          next if extracted_classification_data[:external_key].blank?

                          import_classification(
                            utility_object:,
                            classification_data: extracted_classification_data.merge({ tree_name: }),
                            parent: load_parent_classification_alias.call(raw_classification_data, external_source_id, options)
                          )

                          raw_classification_data_stack +=
                            if with_filters && !filter_object?(load_child_classifications)
                              load_child_classifications.call(mongo_item, raw_classification_data, locale, filter_object.legacy_source_filter).to_a
                            elsif filter_object?(load_child_classifications)
                              load_child_classifications.call(filter_object:, data: raw_classification_data, options:).to_a
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
                            logging.phase_partial(step_label, item_count, times)
                          end

                          break if options[:max_count] && item_count >= options[:max_count]
                        rescue StandardError => e
                          logging.error_instrument(
                            exception: e,
                            external_system: utility_object.external_source,
                            step_label:,
                            channel: 'object_import_failed.datacycle',
                            namespace: 'importer',
                            item_id: raw_classification_data['id']
                          )
                          raise if Rails.env.local?
                        end
                      end

                      times << Time.current
                      logging.phase_partial(step_label, item_count, times)
                    end
                  rescue StandardError => e
                    logging.phase_failed(e, utility_object.external_source, step_label, utility_object.step_name, 'import_failed.datacycle')
                  ensure
                    logging.phase_finished(step_label, item_count, Time.current - times.first)
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
            utility_object.with_mongodb do
              each_locale(utility_object.locales) do |locale|
                I18n.with_locale(locale) do
                  item_count = 0
                  step_label = utility_object.step_label(options.merge({ locales: [locale] }))
                  start_time = Time.current

                  begin
                    logging.phase_started(step_label)

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
                          parent: nil
                        )

                        extract_child_data.call(options, classification_data).each do |child_classification_data|
                          import_classification(
                            utility_object:,
                            classification_data: child_classification_data.merge({ tree_name: }),
                            parent: load_parent_classification_alias.call(classification_data, external_source_id, options)
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
                    logging.phase_finished(step_label, item_count, Time.current - start_time)
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
            utility_object.with_mongodb do
              importer_name = options.dig(:import, :name)
              phase_name = utility_object.source_type.collection_name

              each_locale(utility_object.locales) do |locale|
                I18n.with_locale(locale) do
                  start_time = Time.current
                  step_label = utility_object.step_label(options.merge({ locales: [locale] }))
                  logging.phase_started(step_label)
                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    classification_processing.call(mongo_item, logging, utility_object, locale, tree_name, options.merge({ importer_name:, phase_name: }))
                  end
                ensure
                  logging.phase_finished(step_label, nil, Time.current - start_time)
                end
              end
            end
          end
        end

        # One concept per imported node: the Classification and the ClassificationAlias this used to
        # keep in step are the same record now, so the ClassificationGroup and the ClassificationTree
        # that joined them are gone with them.
        #
        # +classification_data+ comes from the connector's own extract_data lambda, so its keys stay
        # as they are - including :classification_polygons_attributes, which is handed on under the
        # name Concept's nested attributes writer expects.
        #
        # @param parent [DataCycleCore::Concept, nil] what load_parent_classification_alias resolved
        # @return [DataCycleCore::Concept, nil] nil only when the node carries no name
        def import_classification(utility_object:, classification_data:, parent: nil)
          return if classification_data[:name].blank?

          external_system_id = utility_object.external_source.id
          external_system_id = nil if utility_object.options.dig('import', 'no_external_source_id')

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

            concept = find_imported_concept(external_system_id:, classification_data:)
            # A parent decides the scheme - the tree_name only has to answer for a root. That is what
            # the dropped update_classification_tree_tree_label_id_trigger enforced from the database
            # side, and concepts_propagate_scheme_trigger only fires on an UPDATE.
            concept_scheme = parent&.concept_scheme || imported_concept_scheme(external_system_id:, tree_name: classification_data[:tree_name])

            attributes = concept_attributes(classification_data, concept)

            if concept.nil?
              concept_scheme.concepts.create!(external_system_id:, parent_concept: parent, **attributes)
            else
              concept.update!(**attributes)
              concept.move_to_scheme(parent&.id, concept_scheme.id)
              concept
            end
          end
        end

        private

        # Not scoped to the tree, the way the Classification lookup this replaces was not: a node whose
        # external_key moves to another tree is found here and then moved, rather than duplicated.
        def find_imported_concept(external_system_id:, classification_data:)
          if classification_data[:external_key].blank?
            DataCycleCore::Concept.find_by(external_system_id:, internal_name: classification_data[:name])
          else
            DataCycleCore::Concept.find_by(external_system_id:, external_key: classification_data[:external_key])
          end
        end

        def imported_concept_scheme(external_system_id:, tree_name:)
          DataCycleCore::ConceptScheme.find_or_create_by(external_system_id:, name: tree_name, external_key: tree_name) do |item|
            item.visibility = DataCycleCore.default_classification_visibilities
          end
        end

        # A re-import delivers the polygon again, and nested attributes would add a second row unless
        # the one already stored is named - there is at most one per concept.
        #
        # Blanks are dropped so a partial re-import cannot erase a description or a uri that is
        # already there, which is why +assignable+ has to be merged past that: it is a boolean
        # defaulting to true in the database, and `false` is blank?.
        def concept_attributes(classification_data, concept)
          attributes = classification_data
            .slice(:description, :uri, :external_key)
            .merge(concept_polygons_attributes: classification_data[:classification_polygons_attributes])
            .compact_blank

          attributes[:concept_polygons_attributes]&.first&.[]=(:id, concept&.concept_polygons&.first&.id)
          attributes
            .merge(classification_data.slice(:assignable).compact)
            .merge(name: classification_data[:name])
        end
      end
    end
  end
end
