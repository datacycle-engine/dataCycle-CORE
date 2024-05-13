# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportConceptSchemes
        module ClassMethods
          ALLOWED_CONCEPT_SCHEME_KEYS = [:external_key, :name, :external_source_id, :updated_at, :created_at].freeze

          def import_data(utility_object:, options:)
            DataCycleCore::Generic::Common::ImportFunctions.import_concept_schemes(
              utility_object:,
              iterator: method(:load_concept_schemes).to_proc,
              data_processor: method(:process_content).to_proc,
              external_system_processor: method(:external_system_identifiers_to_ids).to_proc,
              options:
            )
          end

          def load_concept_schemes(mongo_item, locale, source_filter)
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
              name = extract_property(raw_data, options, 'name')
              external_id = extract_property(raw_data, options, 'id').presence || name
              external_id_prefix = options.dig(:import, :external_id_prefix)

              return if external_id.blank? || name.blank?

              exclude = options.dig(:import, :exclude_concept_schemes)
              return if exclude.present? && exclude.include?(name)

              concept_scheme_name_mapping = options.dig(:import, :concept_scheme_name_mapping)&.stringify_keys
              name = concept_scheme_name_mapping&.dig(name) || name
              external_system_identifier = extract_property(raw_data, options, 'external_system_identifier')
              external_key = extract_property(raw_data, options, 'external_key') if external_system_identifier.present?
              external_key = [external_id_prefix, external_id].compact_blank.join(' ') if external_key.blank?

              {
                external_key:,
                external_source_id: utility_object.external_source&.id,
                name:,
                external_system_identifier:,
                created_at: Time.zone.now,
                updated_at: Time.zone.now
              }.compact
            end
          end

          def extract_property(data, options, identifier)
            path = options.dig(:import, "concept_scheme_#{identifier}_path".to_sym)
            path.present? ? data.dig(*path.split('.')) : data[identifier]
          end

          def external_system_identifiers_to_ids(data_array:, options:, utility_object:)
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

            concept_schemes_by_name = DataCycleCore::ConceptScheme.where(name: data_array.pluck(:name)).index_by(&:name)

            data_array.map do |da|
              existing = concept_schemes_by_name[da[:name]]
              if existing.present? && existing.external_system_id != da[:external_source_id]
                da[:name] = "#{utility_object.external_source.name} - #{da[:name]}"
              elsif existing.present? && existing.external_system_id == da[:external_source_id]
                da[:external_key] = existing.external_key
              end

              existing = concept_schemes_by_name[da[:name]]
              raise "ConceptScheme (#{da[:name]}) already exists from another source!" if existing.present? && existing.external_system_id != da[:external_source_id]

              da.slice(*ALLOWED_CONCEPT_SCHEME_KEYS)
            end
          end
        end

        extend ClassMethods
      end
    end
  end
end
