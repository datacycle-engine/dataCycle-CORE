# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Common
        CLONED_ATTRIBUTE_EXCEPTIONS = ['id', 'thing_id', 'relation', 'external_key', 'external_source_id'].freeze

        class << self
          def copy(computed_parameters:, **_args)
            computed_parameters.values.first
          end

          def take_first(computed_parameters:, computed_definition:, **_args)
            computed_parameters.each_value do |val|
              return val if val.present?
            end

            return [] if computed_definition.dig('type')&.in?(['embedded', 'linked', 'classification'])

            nil
          end

          def copy_embedded(computed_parameters:, computed_definition:, **_args)
            return [] unless computed_definition.dig('type') == 'embedded'
            return_values = []
            computed_parameters.each_value do |param_value|
              Array.wrap(param_value).each do |value|
                include = true
                Array.wrap(computed_definition.dig('compute', 'value')).each do |config|
                  unless data_in_filter?(value, config['filter'])
                    include = false
                    break
                  end
                end
                return_values << value if include
              end
            end
            return_values
          end

          def get_values_from_hash(data:, key_path:, filter: nil, limit: nil, external_key_prefix: [])
            return data if key_path.blank?
            return if data.blank?
            external_key_prefix = Array.wrap(external_key_prefix)
            return attribute_value_from_hash(data:, key_path:, filter:, external_key_prefix:) if data.is_a?(::Hash)

            if data.is_a?(::Array) && data.first.is_a?(ActiveRecord::Base) || data.is_a?(ActiveRecord::Relation)
              new_data = (limit.to_i.positive? ? data.first(limit) : data)
              new_value = ->(v) { v.to_h_partial([key_path.first, 'id', *filter&.pluck('key')&.flatten&.uniq]) }
            elsif data.is_a?(::Array) && data.first.to_s.uuid?
              new_data = DataCycleCore::Thing.where(id: data).by_ordered_values(data).limit(limit)
              new_value = ->(v) { v.to_h_partial([key_path.first, 'id', *filter&.pluck('key')&.flatten&.uniq]) }
            elsif data.is_a?(::Array)
              new_data = (limit.to_i.positive? ? data.first(limit) : data)
              new_value = ->(v) { v }
            end

            return if new_data.blank?

            return_value = new_data.map { |v| get_values_from_hash(data: new_value.call(v), key_path:, filter:, external_key_prefix:) }
            exptects_array = return_value.all?(::Array)
            return_value.reject! { |v| DataHashService.blank?(v) }
            return return_value if DataHashService.present?(return_value)

            # return correct type if all values are empty
            exptects_array ? [[]] : []
          end

          def attribute_value_by_first_match(computed_parameters:, computed_definition:, **_args)
            Array.wrap(computed_definition.dig('compute', 'value')).each do |config|
              value = Array.wrap(get_values_from_hash(data: computed_parameters, key_path: config['attribute'].split('.'), filter: config['filter'], external_key_prefix: content&.id)).compact.first

              return value if DataHashService.present?(value)
            end

            nil
          end

          def attribute_values_from_linked(computed_parameters:, computed_definition:, content:, **_args)
            values = []
            Array.wrap(computed_definition.dig('compute', 'value')).each do |config|
              values += Array.wrap(get_values_from_hash(data: computed_parameters, key_path: config['attribute'].split('.'), filter: config['filter'], external_key_prefix: content&.id)).compact
            end

            values
          end

          def attribute_value_from_first_existing_linked(computed_parameters:, computed_definition:, content:, **_args)
            computed_definition.dig('compute', 'parameters').each do |config|
              key_path = config.split('.')
              value = Array.wrap(get_values_from_hash(data: computed_parameters, key_path:, external_key_prefix: content&.id)).compact.first

              return value if DataHashService.present?(computed_parameters.dig(key_path.first))
            end

            nil
          end

          def attribute_value_from_first_linked(computed_parameters:, computed_definition:, content:, **_args)
            computed_definition.dig('compute', 'parameters').each do |config|
              value = Array.wrap(get_values_from_hash(data: computed_parameters, key_path: config.split('.'), limit: 1, external_key_prefix: content&.id)).compact.first

              return value if DataHashService.present?(value)
            end

            nil
          end

          # does not work for embedded or schedule attributes
          def overlay(computed_parameters:, computed_definition:, **_args)
            raise "Cloning #{computed_definition.dig('type')} is not implemented yet" if computed_definition.dig('type').in?(Content::Content::EMBEDDED_PROPERTY_TYPES + Content::Content::SCHEDULE_PROPERTY_TYPES + Content::Content::TIMESERIES_PROPERTY_TYPES + Content::Content::ASSET_PROPERTY_TYPES)

            allowed_postfixes = MasterData::Templates::Extensions::Overlay.allowed_postfixes_for_type(computed_definition['type'])

            override_value = computed_parameters.detect { |k, _v| k.ends_with?(MasterData::Templates::Extensions::Overlay::BASE_OVERLAY_POSTFIX) }&.last if allowed_postfixes.include?(MasterData::Templates::Extensions::Overlay::BASE_OVERLAY_POSTFIX)

            return override_value if DataHashService.present?(override_value)

            add_value = computed_parameters.detect { |k, _v| k.ends_with?(MasterData::Templates::Extensions::Overlay::ADD_OVERLAY_POSTFIX) }&.last if allowed_postfixes.include?(MasterData::Templates::Extensions::Overlay::ADD_OVERLAY_POSTFIX)
            original_value = computed_parameters.first.last

            return original_value if DataHashService.blank?(add_value)

            Array.wrap(original_value) + Array.wrap(add_value)
          end

          private

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
                      item.respond_to?(key) ? item.attribute_to_h(key) : nil
                    end

            return if key_path.one? && filter.present? && !data_in_filter?(data, filter)

            value = clone_attribute_value(value:, external_key_prefix: external_key_prefix + key_path) if key_path.length <= 1

            get_values_from_hash(data: value, key_path: key_path.drop(1), filter:, external_key_prefix:)
          end

          def clone_attribute_value(value:, resolve: true, external_key_prefix: [])
            return value unless (value.is_a?(::Hash) || value.is_a?(::Array)) && DataHashService.present?(value)

            if value.is_a?(::Array)
              cloned_value = value.map { |v| clone_attribute_value(value: v, resolve: false, external_key_prefix:) } if value.is_a?(::Array)
            else
              cloned_value = value.with_indifferent_access
              if value['id'].present? && value['id'].to_s.uuid?
                cloned_value.except!(*CLONED_ATTRIBUTE_EXCEPTIONS)
                cloned_value['external_key'] = [*external_key_prefix, value['id']].compact.join('_')
                cloned_value['id'] = Generic::Common::DataReferenceTransformations::ExternalReference.new(cloned_value.key?('start_time') ? :schedule : :content, nil, cloned_value['external_key'])
              end

              cloned_value.each do |k, v|
                cloned_value[k] = clone_attribute_value(value: v, resolve: false, external_key_prefix: external_key_prefix + [value['id'], k].compact) if v.is_a?(::Hash) || v.is_a?(::Array)
              end
            end

            cloned_value = Generic::Common::DataReferenceTransformations.resolve_references(cloned_value) if resolve
            cloned_value
          end

          def data_in_filter?(data, filter)
            return true unless data.is_a?(::Hash)

            Array.wrap(filter).each do |config|
              in_filter = case config['type']
                          when 'classification'
                            id = DataCycleCore::ClassificationAlias.joins(:classification_alias_path).find_by(classification_alias_path: { full_path_names: config['value'].split('>').map(&:strip).reverse })&.primary_classification&.id
                            next false if id.nil?

                            Array.wrap(config['key']).any? { |k| Array.wrap(get_values_from_hash(data, [k])).include?(id) }
                          else
                            get_values_from_hash(data, [config['type']]) == config['value']
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
