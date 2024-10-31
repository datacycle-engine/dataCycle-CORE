# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportConcepts
        module ClassMethods
          ALLOWED_CONCEPT_KEYS = [:external_key, :external_source_id, :name, :description, :uri, :order_a, :parent_external_key].freeze

          def import_data(utility_object:, options:)
            DataCycleCore::Generic::Common::ImportFunctions.import_concepts(
              utility_object:,
              iterator: method(:load_concepts).to_proc,
              data_processor: method(:process_content).to_proc,
              data_transformer: method(:transform_data_array).to_proc,
              data_mapping_processor: method(:transform_concept_mappings).to_proc,
              options:
            )
          end

          def load_concepts(mongo_item, locale, source_filter)
            mongo_item.where(
              I18n.with_locale(locale) { source_filter.with_evaluated_values }
                .merge(
                  "dump.#{locale}": { '$exists': true },
                  "dump.#{locale}.deleted_at": { '$exists': false }
                )
            )
          end

          def process_content(utility_object:, raw_data:, locale:, options:)
            return if raw_data.blank?
            return if options&.blank? || options.dig(:import).blank?
            allowed_locales = (
              options.dig(:import, :locales) ||
              utility_object.external_source.try(:default_options)&.symbolize_keys&.dig(:locales) ||
              [locale]
            ).map(&:to_s)

            return unless allowed_locales.include?(locale.to_s)

            I18n.with_locale(locale) do
              external_id = extract_property(raw_data, options, 'id')
              name = extract_property(raw_data, options, 'name')
              external_id_prefix = options.dig(:import, :external_id_prefix) ||
                                   extract_property(raw_data, options, 'external_id_prefix')
              concept_scheme_external_id_prefix = options.dig(:import, :concept_scheme_external_id_prefix) ||
                                                  extract_property(raw_data, options, 'concept_scheme_external_id_prefix')
              parent_id = extract_property(raw_data, options, 'parent_id')
              external_system_identifier = extract_property(raw_data, options, 'external_system_identifier')

              return if external_id.blank? || name.blank?
              return if external_system_identifier.in?(Array.wrap(options[:current_instance_identifiers]))

              parent_id = nil if parent_id == external_id # concept cannot be its own parent

              {
                external_key: [external_id_prefix, external_id].compact_blank.join,
                external_source_id: utility_object.external_source.id,
                name:,
                parent_external_key: parent_id.presence&.then { |pid| [external_id_prefix, pid].compact_blank.join },
                external_system_identifier:,
                description: extract_property(raw_data, options, 'description'),
                uri: extract_property(raw_data, options, 'uri'),
                order_a: extract_property(raw_data, options, 'order_a'),
                concept_scheme_external_key: [
                  concept_scheme_external_id_prefix,
                  extract_property(raw_data, options, 'concept_scheme_external_key')
                ].compact_blank.join,
                concept_scheme_name: extract_property(raw_data, options, 'concept_scheme_name').presence ||
                  options.dig(:import, :concept_scheme).presence,
                mapped_concepts: extract_property(raw_data, options, 'mapped_concepts')
              }.compact
            end
          end

          def extract_property(data, options, identifier)
            path = options.dig(:import, :"concept_#{identifier}_path")
            path.present? ? data.dig(*path.split('.')) : data[identifier]
          end

          def transform_data_array(data_array:, options:)
            data_array = external_system_identifiers_to_ids!(
              data_array:,
              **options.dig(:import)&.slice(:import_external_systems, :external_systems_mapping)
            )

            transform_concept_scheme_identifiers(data_array:, options:)
          end

          def transform_concept_scheme_identifiers(data_array:, options:)
            concept_scheme_external_keys = data_array
              .filter { |da| da[:concept_scheme_external_key].present? }
              .map { |da|
                {
                  external_system_id: da[:external_source_id],
                  external_key: da[:concept_scheme_external_key]
                }
              }
              .uniq

            if concept_scheme_external_keys.present?
              concept_schemes_by_key = DataCycleCore::ConceptScheme
                .by_external_systems_and_keys(concept_scheme_external_keys)
                .index_by(&:external_key)
            end

            concept_scheme_names = data_array.pluck(:concept_scheme_name).compact_blank.uniq
            if concept_scheme_names.present?
              concept_scheme_name_mapping = options.dig(:import, :concept_scheme_name_mapping)&.stringify_keys
              csn_mapping_inverted = concept_scheme_name_mapping&.invert
              concept_scheme_names.map! { |csn| concept_scheme_name_mapping&.dig(csn) || csn }
              concept_schemes_by_name = DataCycleCore::ConceptScheme
                .where(name: concept_scheme_names)
                .index_by { |cs| csn_mapping_inverted&.dig(cs.name) || cs.name }
            end
            concept_schemes = concept_schemes_by_key.to_h.merge(concept_schemes_by_name.to_h)

            data_array
              .group_by { |da| da[:concept_scheme_external_key].presence || da[:concept_scheme_name] }
              .to_h { |k, v|
              new_k = concept_schemes[k]
              next [nil, nil] if new_k.blank? # reject if concept scheme is missing
              [
                new_k,
                v.map { |da|
                  next if new_k.external_system_id != da[:external_source_id]
                  da.slice(*ALLOWED_CONCEPT_KEYS)
                }.compact.presence
              ]
            }
              .compact_blank
          end

          def external_system_identifiers_to_ids!(data_array:, import_external_systems: false, external_systems_mapping: nil)
            external_system_identifiers = data_array.pluck(:external_system_identifier).compact.uniq
            es_mapping = external_systems_mapping.to_h.stringify_keys

            if external_system_identifiers.present?
              mapped_es_identifiers = external_system_identifiers.map { |esi| es_mapping[esi] || esi }.uniq
              external_systems = DataCycleCore::ExternalSystem.by_names_or_identifiers(mapped_es_identifiers).select(:id, :name, :identifier).as_json
              external_system_slugs = external_systems.pluck('name', 'identifier').flatten
              missing_systems = mapped_es_identifiers.filter { |esi| external_system_slugs.exclude?(esi) }

              if missing_systems.present? && import_external_systems
                now = Time.zone.now
                new_systems = DataCycleCore::ExternalSystem.insert_all(missing_systems.map { |ms| { name: ms, identifier: ms, created_at: now, updated_at: now } }, returning: [:id, :identifier, :name])
                external_systems += new_systems
              end

              data_array.filter { |da| da[:external_system_identifier].present? }.each do |da|
                es_identifier = es_mapping[da[:external_system_identifier]] || da[:external_system_identifier]
                es_id = external_systems.find { |es|
                  es['identifier'] == es_identifier ||
                    es['name'] == es_identifier
                }&.dig('id')
                da[:external_source_id] = es_id if es_id.present?
                da.delete(:external_system_identifier)
              end
            end

            data_array
          end

          def transform_concept_mappings(data_array:, utility_object:, options:)
            concept_mappings = map_concept_mappings(data_array:, utility_object:)

            external_system_identifiers_to_ids!(
              data_array: concept_mappings.pluck(:child),
              import_external_systems: false,
              external_systems_mapping: options.dig(:import, :external_systems_mapping)
            )

            mappings_for_existing_concepts(concept_mappings:)
          end

          def mappings_for_existing_concepts(concept_mappings:)
            full_paths = concept_mappings.map { |cm| cm.dig(:child, :full_path) }.uniq
            concepts_by_path = DataCycleCore::Concept.by_full_paths(full_paths).index_by(&:full_path)
            filtered_mappings = concept_mappings
              .filter { |cm| cm.dig(:child, :external_key).present? }
              .pluck(:parent, :child)
              .flatten

            existing_concepts = DataCycleCore::Concept
              .by_external_sources_and_keys(filtered_mappings)
              .index_by { |co| [co.external_system_id, co.external_key] }

            concept_mappings.map { |cm|
              parent = existing_concepts[[cm[:parent][:external_source_id], cm[:parent][:external_key]]]
              child = concepts_by_path[cm[:child][:full_path]] || existing_concepts[[cm[:child][:external_source_id], cm[:child][:external_key]]]

              next if parent.blank? || child.blank?

              {
                parent_id: parent.id,
                child_id: child.id,
                link_type: 'related'
              }
            }.compact
          end

          def map_concept_mappings(data_array:, utility_object:)
            concept_mappings = []
            data_array.each do |da|
              next if da[:mapped_concepts].blank?

              da[:mapped_concepts].each do |mc|
                if mc[:external_key].present?
                  concept_mappings << {
                    parent: {
                      external_key: da[:external_key],
                      external_source_id: da[:external_source_id]
                    },
                    child: {
                      external_key: mc[:external_key],
                      external_source_id: utility_object.external_source.id,
                      external_system_identifier: mc[:external_system_identifier],
                      full_path: mc[:full_path]
                    }
                  }
                end

                concept_mappings << {
                  parent: {
                    external_key: da[:external_key],
                    external_source_id: da[:external_source_id]
                  },
                  child: {
                    external_key: mc[:id],
                    external_source_id: utility_object.external_source.id,
                    full_path: mc[:full_path]
                  }
                }
              end
            end

            concept_mappings
          end
        end

        extend ClassMethods
      end
    end
  end
end
