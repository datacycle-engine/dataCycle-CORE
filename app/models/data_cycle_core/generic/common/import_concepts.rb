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
              external_system_processor: method(:transform_data_array).to_proc,
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
            allowed_locales = (options.dig(:import, :locales) || utility_object.external_source.try(:default_options)&.symbolize_keys&.dig(:locales) || [locale]).map(&:to_s)

            return unless allowed_locales.include?(locale.to_s)

            I18n.with_locale(locale) do
              external_id = extract_property(raw_data, options, 'id')
              external_id_prefix = options.dig(:import, :external_id_prefix)
              concept_scheme_external_id_prefix = options.dig(:import, :concept_scheme_external_id_prefix)

              return if external_id.blank?

              {
                external_key: [external_id_prefix, external_id].compact_blank.join(' '),
                external_source_id: utility_object.external_source.id,
                name: extract_property(raw_data, options, 'name'),
                parent_external_key: [
                  external_id_prefix,
                  extract_property(raw_data, options, 'parent_id')
                ].compact_blank.join(' ').presence,
                external_system_identifier: extract_property(raw_data, options, 'external_system_identifier'),
                description: extract_property(raw_data, options, 'description'),
                uri: extract_property(raw_data, options, 'uri'),
                order_a: extract_property(raw_data, options, 'order_a'),
                concept_scheme_external_key: [
                  concept_scheme_external_id_prefix,
                  extract_property(raw_data, options, 'concept_scheme_external_key')
                ].compact_blank.join(' '),
                concept_scheme_name: extract_property(raw_data, options, 'concept_scheme_name').presence || options.dig(:import, :concept_scheme).presence
              }.compact
            end
          end

          def extract_property(data, options, identifier)
            path = options.dig(:import, "concept_#{identifier}_path".to_sym)
            path.present? ? data.dig(*path.split('.')) : data[identifier]
          end

          def transform_data_array(data_array:, options:)
            data_array = external_system_identifiers_to_ids(data_array:, options:)

            transform_concept_scheme_identifiers(data_array:)
          end

          def transform_concept_scheme_identifiers(data_array:)
            concept_scheme_external_keys = data_array
              .filter { |da| da[:concept_scheme_external_key].present? }
              .map { |da| { external_system_id: da[:external_source_id], external_key: da[:concept_scheme_external_key] } }
              .uniq

            if concept_scheme_external_keys.present?
              concept_schemes_by_key = DataCycleCore::ConceptScheme
                .by_external_systems_and_keys(concept_scheme_external_keys)
                .index_by(&:external_key)
            end

            concept_scheme_names = data_array.pluck(:concept_scheme_name).compact_blank.uniq
            if concept_scheme_external_keys.present?
              concept_schemes_by_name = DataCycleCore::ConceptScheme
                .where(name: concept_scheme_names)
                .index_by(&:name)
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

          def external_system_identifiers_to_ids(data_array:, options:)
            external_system_identifiers = data_array.pluck(:external_system_identifier).compact.uniq

            if external_system_identifiers.present?
              external_systems = DataCycleCore::ExternalSystem.by_names_or_identifiers(external_system_identifiers).select(:id, :name, :identifier).as_json
              external_system_slugs = external_systems.pluck('name', 'identifier').flatten
              missing_systems = external_system_identifiers.filter { |esi| external_system_slugs.exclude?(esi) }

              if missing_systems.present? && options.dig(:import, :import_external_systems)
                now = Time.zone.now
                new_systems = DataCycleCore::ExternalSystem.insert_all(missing_systems.map { |ms| { name: ms, identifier: ms, created_at: now, updated_at: now } }, returning: [:id, :identifier, :name])
                external_systems += new_systems
              end

              data_array.filter { |da| da[:external_system_identifier].present? }.each do |da|
                es_id = external_systems.find { |es| es['identifier'] == da[:external_system_identifier] || es['name'] == da[:external_system_identifier] }&.dig('id')
                da[:external_source_id] = es_id if es_id.present?
              end
            end

            data_array
          end
        end

        extend ClassMethods
      end
    end
  end
end
