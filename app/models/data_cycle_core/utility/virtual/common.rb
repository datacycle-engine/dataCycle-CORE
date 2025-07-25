# frozen_string_literal: true

raise 'ActiveRecord::Relation#load_records is no longer available, check patch!' unless ActiveRecord::Relation.method_defined? :load_records
raise 'ActiveRecord::Relation#load_records arity != 1, check patch!' unless ActiveRecord::Relation.instance_method(:load_records).arity == 1

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
              val = virtual_key.split('.').reduce(content) { |value, key| value.try(key) }
              return val if DataHashService.present?(val)
            end

            DataHashService.none_by_property_type(virtual_definition['type'])
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
                content_part&.send(params['attribute'])&.find { |c| c.name == I18n.t(params['name'], default: params['name']) } ||
                  content_part&.send(params['attribute'])&.find { |c| c.name == I18n.t(params['name'], default: params['name']&.split('.')&.last) }
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
              value = content.send(virtual_parameters.first)

              return DataCycleCore::Thing.none if value.first.nil?

              DataCycleCore::Thing.default_scoped.where(id: value.first.id).tap { |rel| rel.send(:load_records, [value.first]) }
            else
              DataCycleCore::Thing.none
            end
          end

          def content_classification_for_tree(virtual_definition:, content:, **_args)
            content.classifications_for_tree(tree_name: virtual_definition['tree_label'])
          end

          def attribute_value_by_first_match(virtual_definition:, content:, **_args)
            Array.wrap(virtual_definition.dig('virtual', 'value')).each do |config|
              value = get_value_by_filter(content, config['attribute'].split('.'), config['filter'])

              return value if DataHashService.present?(value)
            end

            nil
          end

          def overlay(virtual_parameters:, content:, virtual_definition:, **_args)
            allowed_postfixes = MasterData::Templates::Extensions::Overlay.allowed_postfixes_for_type(virtual_definition['type'])

            override_key = virtual_parameters.detect { |v| v.ends_with?(MasterData::Templates::Extensions::Overlay::BASE_OVERLAY_POSTFIX) } if allowed_postfixes.include?(MasterData::Templates::Extensions::Overlay::BASE_OVERLAY_POSTFIX)
            override_value = content.try(override_key) if override_key.present?

            if DataHashService.present?(override_value)
              return override_value unless virtual_definition['type'] == 'object'

              original_value = content.try(virtual_parameters.first)
              return override_value if DataHashService.blank?(original_value)

              return original_value.merge(override_value)
            end

            add_key = virtual_parameters.detect { |v| v.ends_with?(MasterData::Templates::Extensions::Overlay::ADD_OVERLAY_POSTFIX) } if allowed_postfixes.include?(MasterData::Templates::Extensions::Overlay::ADD_OVERLAY_POSTFIX)
            add_value = content.try(add_key) if add_key.present?
            original_value = content.try(virtual_parameters.first)

            return original_value if DataHashService.blank?(add_value)

            new_value = original_value + add_value
            new_value.first.class.by_ordered_values(new_value.pluck(:id)).tap { |rel| rel.send(:load_records, new_value) }
          end

          private

          def get_value_by_filter(content, path, filter)
            I18n.with_locale(content.try(:first_available_locale) || I18n.locale) do
              key, *new_path = path

              data = content.try(key)
              data = filtered_data(data:, filter:, key:) if filter.present?

              return data if new_path.blank? && DataCycleCore::DataHashService.present?(data)
              return unless key.in?(content.embedded_property_names + content.linked_property_names + content.classification_property_names)

              data&.each do |v|
                value = get_value_by_filter(v, new_path, filter)

                return value if DataHashService.present?(value)
              end

              nil
            end
          end

          def content_in_filter?(content, filter, key)
            return true if key.blank?

            Array.wrap(filter).each do |config|
              next unless config['target'].blank? || key&.in?(Array.wrap(config['target']))

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

          def filtered_data(data:, filter:, key:)
            return data if DataCycleCore::DataHashService.blank?(data)

            if data.is_a?(ActiveRecord::Base)
              content_in_filter?(data, filter, key) ? data : {}
            elsif (data.is_a?(::Array) && data.first.is_a?(ActiveRecord::Base)) || data.is_a?(ActiveRecord::Relation)
              value = data.to_a.select { content_in_filter?(_1, filter, key) }
              DataCycleCore::DataHashService.blank?(value) ? value : value.first.class.unscoped.by_ordered_values(value.pluck(:id)).tap { _1.send(:load_records, value) }
            else
              data
            end
          end
        end
      end
    end
  end
end
