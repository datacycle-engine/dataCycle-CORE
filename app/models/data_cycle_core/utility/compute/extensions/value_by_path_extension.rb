# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Extensions
        module ValueByPathExtension
          extend ActiveSupport::Concern

          CLONED_ATTRIBUTE_EXCEPTIONS = ['id', 'thing_id', 'relation', 'external_key', 'external_source_id'].freeze

          private

          def get_values_from_hash(data:, key_path:, filter: nil, limit: nil, external_key_prefix: [], current_key: nil)
            data = filtered_data(data:, filter:, current_key:) if filter.present?
            return data if key_path.blank?
            return if DataHashService.blank?(data)
            external_key_prefix = Array.wrap(external_key_prefix)
            return attribute_value_from_hash(data:, key_path:, filter:, external_key_prefix:) if data.is_a?(::Hash)

            if data.is_a?(::Array) && data.first.is_a?(ActiveRecord::Base) || data.is_a?(ActiveRecord::Relation)
              limited_value = (limit.to_i.positive? ? data.first(limit) : data)
              new_value_proc = -> { _1.to_h_partial([key_path.first, 'id', *filter&.pluck('key')&.flatten&.uniq]) }
            elsif data.is_a?(::Array) && data.first.to_s.uuid?
              limited_value = DataCycleCore::Thing.where(id: data).by_ordered_values(data).limit(limit)
              new_value_proc = -> { _1.to_h_partial([key_path.first, 'id', *filter&.pluck('key')&.flatten&.uniq]) }
            elsif data.is_a?(::Array)
              limited_value = (limit.to_i.positive? ? data.first(limit) : data)
              new_value_proc = -> { _1 }
            end

            return if limited_value.blank?

            return_value = limited_value.map { |v| get_values_from_hash(data: new_value_proc.call(v), key_path:, filter:, external_key_prefix:, current_key:) }
            exptects_array = return_value.all?(::Array)
            return_value.reject! { |v| DataHashService.blank?(v) }
            return return_value if DataHashService.present?(return_value)

            # return correct type if all values are empty
            exptects_array ? [[]] : []
          end

          def base_key_prefix(content:, key:)
            external_key_prefix = [content&.id]
            external_key_prefix << I18n.locale.to_s if content&.translatable_property_names&.include?(key)
            external_key_prefix
          end

          def attribute_value_from_hash(data:, key_path:, filter:, external_key_prefix: [])
            key = key_path.first
            value = if data.key?(key)
                      data.dig(key)
                    elsif data.dig('datahash')&.key?(key)
                      data.dig('datahash', key)
                    elsif data.dig('translations', I18n.locale.to_s)&.key?(key)
                      data.dig('translations', I18n.locale.to_s, key)
                    else
                      id = data.dig('id') || data.dig('datahash', 'id') || data.dig('translations', I18n.locale.to_s, 'id')
                      item = DataCycleCore::Thing.find_by(id:)
                      item&.property?(key) ? item.attribute_to_h(key) : nil
                    end

            value = clone_attribute_value(value:, external_key_prefix: external_key_prefix + key_path) if key_path.length <= 1

            get_values_from_hash(data: value, key_path: key_path.drop(1), filter:, external_key_prefix:, current_key: key)
          end

          def filtered_data(data:, filter:, current_key:)
            if data.is_a?(::Hash)
              data_in_filter?(current_key, data, filter) ? data : {}
            elsif data.is_a?(::Array)
              data.select { data_in_filter?(current_key, _1, filter) }
            else
              data
            end
          end

          def clone_attribute_value(value:, resolve: true, external_key_prefix: [])
            return value unless (value.is_a?(::Hash) || value.is_a?(::Array)) && DataHashService.present?(value)

            if value.is_a?(::Array)
              cloned_value = value.map { |v| clone_attribute_value(value: v, resolve: false, external_key_prefix:) }
            else
              cloned_value = value.with_indifferent_access

              if cloned_value.key?('external_key') || cloned_value.key?('id')
                external_key = Digest::SHA1.hexdigest(value.to_json)
                cloned_value.except!(*CLONED_ATTRIBUTE_EXCEPTIONS)
                cloned_value['external_key'] = [*external_key_prefix, external_key].compact.join('_')
                cloned_value['id'] = Generic::Common::DataReferenceTransformations::ExternalReference.new(cloned_value.key?('start_time') ? :schedule : :content, nil, cloned_value['external_key'])
              end

              cloned_value.each do |k, v|
                cloned_value[k] = clone_attribute_value(value: v, resolve: false, external_key_prefix: external_key_prefix + [external_key, k].compact) if v.is_a?(::Hash) || v.is_a?(::Array)
              end
            end

            cloned_value = Generic::Common::DataReferenceTransformations.resolve_references(cloned_value) if resolve
            cloned_value
          end

          def data_in_filter?(key, data, filter)
            return true unless data.is_a?(::Hash) && key.present?

            Array.wrap(filter).each do |config|
              next unless config['target'].blank? || key&.in?(Array.wrap(config['target']))

              in_filter = case config['type']
                          when 'classification'
                            id = DataCycleCore::Concept.by_full_paths(config['value']).first&.classification_id
                            next false if id.nil?

                            Array.wrap(config['key']).any? { |k| Array.wrap(get_values_from_hash(data:, key_path: [k])).include?(id) }
                          else
                            get_values_from_hash(data:, key_path: [config['type']]) == config['value']
                          end

              return false unless in_filter
            end

            true
          end
        end
      end
    end
  end
end
