# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Common
        class << self
          def copy_plain(virtual_parameters:, content:, **_args)
            content.try(virtual_parameters.first)
          end

          def take_first(virtual_parameters:, virtual_definition:, content:, **_args)
            virtual_parameters.each do |virtual_key|
              val = content.try(virtual_key.to_sym)
              return val if val.present?
            end

            case virtual_definition.dig('type')
            when 'embedded', 'linked'
              DataCycleCore::Thing.none
            when 'classification'
              DataCycleCore::Classification.none
            end
          end

          def value_from_definition(virtual_definition:, content:, **_args)
            path = virtual_definition.dig('virtual', 'path')

            return if path.blank?

            content&.property_definitions&.dig(*path)
          end

          def attribute_value_from_named_embedded(virtual_parameters:, content:, **_args)
            virtual_parameters.reduce(content) do |content_part, params|
              if !content_part.respond_to?(params['attribute'])
                nil
              elsif params['name']
                content_part
                  &.send(params['attribute'])
                  &.find do |c|
                    c.name == I18n.t(params['name'], default: params['name'])
                  end
              else
                content_part&.send(params['attribute'])
              end
            end
          end

          def attribute_value_from_first_linked(virtual_parameters:, content:, **_args)
            virtual_parameters.reduce(content) do |content_part, attribute_name|
              if content_part.is_a?(Enumerable) && content_part.first.respond_to?(attribute_name)
                content_part.first&.send(attribute_name)
              elsif content_part.is_a?(DataCycleCore::Thing) && content_part.respond_to?(attribute_name)
                content_part&.send(attribute_name)
              end
            end
          end

          def take_first_linked(virtual_parameters:, content:, **_args)
            if content.respond_to?(virtual_parameters.first)
              content.send(virtual_parameters.first)&.limit(1) || []
            else
              []
            end
          end

          def content_classification_for_tree(virtual_definition:, content:, **_args)
            content.classifications_for_tree(tree_name: virtual_definition['tree_label'])
          end

          def attribute_value_by_first_match(virtual_definition:, content:, **_args)
            Array.wrap(virtual_definition.dig('virtual', 'value')).each do |config|
              value = get_value_by_filter(content, config['attribute'].split('.'), config['filter'])

              return value if DataCycleCore::DataHashService.present?(value)
            end

            nil
          end

          private

          def get_value_by_filter(content, path, filter)
            I18n.with_locale(content.first_available_locale) do
              key, *new_path = path

              return content.send(key) if new_path.blank? && DataCycleCore::DataHashService.present?(content.try(key))
              return unless key.in?(content.embedded_property_names + content.linked_property_names)

              content.try(key)&.each do |item|
                next if filter.present? && new_path.one? && !content_in_filter?(item, filter)

                value = get_value_by_filter(item, new_path, filter)

                next if DataCycleCore::DataHashService.blank?(value)

                return value
              end

              nil
            end
          end

          def content_in_filter?(content, filter)
            Array.wrap(filter).each do |config|
              in_filter = case config['type']
                          when 'classification'
                            content.classification_aliases.joins(:classification_alias_path).exists?(classification_alias_path: { full_path_names: config['value'].split('>').map(&:strip).reverse })
                          else
                            content.try(config['type']) == config['value']
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
