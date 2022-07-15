# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ExternalReferenceTransformations
        def self.add_external_references(data, property_name, external_source_id, external_key_path)
          external_references = external_key_path.reduce(data) { |partial_data, key|
            if partial_data.is_a?(Hash)
              partial_data.select { |k, _v| k == key }.values.flatten
            elsif partial_data.is_a?(Array)
              partial_data.map { |entry| entry.select { |k, _v| k == key }.values }.flatten
            else
              raise 'Invalid class for raw data'
            end
          }.map { |key| ExternalReference.new(external_source_id, key) }

          data.merge({ property_name => external_references })
        end

        def self.resolve_external_references(data)
          collected_external_references = collect_external_references(data)

          mapping_table = collected_external_references.map(&:external_source_id).uniq.map { |external_source_id|
            external_keys = collected_external_references.select { |ref|
              ref.external_source_id == external_source_id
            }.map(&:external_key)

            {
              external_source_id => load_things(external_source_id, external_keys)
            }
          }.reduce(&:merge)

          replace_external_references(data, mapping_table)
        end

        ExternalReference = Struct.new(:external_source_id, :external_key)

        def self.collect_external_references(data)
          if data.is_a?(ExternalReference)
            data
          elsif data.is_a?(Hash)
            data.values.map { |v| collect_external_references(v) }.flatten
          elsif data.is_a?(Array)
            data.map { |v| collect_external_references(v) }.flatten
          else
            []
          end
        end

        def self.replace_external_references(data, mapping_table)
          if data.is_a?(ExternalReference)
            mapping_table.dig(data.external_source_id, data.external_key)
          elsif data.is_a?(Hash)
            data.transform_values { |v| replace_external_references(v, mapping_table) }
          elsif data.is_a?(Array)
            data.map { |v| replace_external_references(v, mapping_table) }.compact
          else
            data
          end
        end

        def self.load_things(external_source_id, external_keys)
          DataCycleCore::Thing.where(external_source_id: external_source_id, external_key: external_keys)
                                .pluck(:external_key, :id).to_h
        end
      end
    end
  end
end
