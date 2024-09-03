# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Common
        extend Extensions::ValueByPathExtension

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

          def copy_embedded(computed_parameters:, computed_definition:, content:, key:, **_args)
            return [] unless computed_definition.dig('type') == 'embedded'

            values = []

            Array.wrap(computed_definition.dig('compute', 'value')).each do |config|
              value = get_values_from_hash(
                data: computed_parameters,
                key_path: config['attribute'].split('.'),
                filter: config['filter'],
                external_key_prefix: base_key_prefix(content:, key:)
              )

              value.reject!(&:blank?)
              values.concat(value) if DataHashService.present?(value)
            end

            values
          end

          def attribute_value_by_first_match(computed_parameters:, computed_definition:, content:, key:, **_args)
            Array.wrap(computed_definition.dig('compute', 'value')).each do |config|
              value = Array.wrap(get_values_from_hash(
                                   data: computed_parameters,
                                   key_path: config['attribute'].split('.'),
                                   filter: config['filter'],
                                   external_key_prefix: base_key_prefix(content:, key:)
                                 )).compact.first

              return value if DataHashService.present?(value)
            end

            nil
          end

          def attribute_values_from_linked(computed_parameters:, computed_definition:, content:, key:, **_args)
            values = []

            Array.wrap(computed_definition.dig('compute', 'value')).each do |config|
              values += Array.wrap(get_values_from_hash(
                                     data: computed_parameters,
                                     key_path: config['attribute'].split('.'),
                                     filter: config['filter'],
                                     external_key_prefix: base_key_prefix(content:, key:)
                                   )).compact
            end

            values
          end

          def attribute_value_from_first_existing_linked(computed_parameters:, computed_definition:, content:, key:, **_args)
            computed_definition.dig('compute', 'parameters').each do |config|
              key_path = config.split('.')
              value = Array.wrap(get_values_from_hash(
                                   data: computed_parameters,
                                   key_path:,
                                   external_key_prefix: base_key_prefix(content:, key:)
                                 )).compact.first

              return value if DataHashService.present?(computed_parameters.dig(key_path.first))
            end

            nil
          end

          def attribute_value_from_first_linked(computed_parameters:, computed_definition:, content:, key:, **_args)
            computed_definition.dig('compute', 'parameters').each do |config|
              value = Array.wrap(get_values_from_hash(
                                   data: computed_parameters,
                                   key_path: config.split('.'),
                                   limit: 1,
                                   external_key_prefix: base_key_prefix(content:, key:)
                                 )).compact.first

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
        end
      end
    end
  end
end
