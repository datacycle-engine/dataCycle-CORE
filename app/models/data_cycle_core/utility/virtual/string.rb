# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module String
        extend DataCycleCore::ContentHelper

        class << self
          def concat(virtual_parameters:, **args)
            virtual_parameters.map { |item|
              item.is_a?(Hash) ? transform_string(item, args) : item
            }.join
          end

          def transform_string(definition, args)
            case definition.dig('type')
            when 'external_source'
              args.dig(:content)&.external_source&.default_options&.dig(definition.dig('name'))
            when 'I18n'
              definition.dig('type').constantize.send(definition.dig('name'))
            when 'content'
              args.dig(:content).send(definition.dig('name'))
            else
              raise 'Unknown type for string transformation'
            end
          end

          def license_uri(content:, **_args)
            content.classification_aliases.for_tree('Lizenzen').reorder(nil).pick(:uri)
          end

          # only works for sync_api
          def to_additional_information(content:, virtual_parameters:, virtual_definition:, **_args)
            template = DataCycleCore::Thing.find_by(template: true, template_name: virtual_definition&.dig('template_name'))

            return if template.nil?

            virtual_parameters.map { |key|
              value = content.try(key)

              next if value.blank?

              template.dup.tap do |t|
                type_of_information = DataCycleCore::ClassificationAlias
                  .for_tree('Informationstypen')
                  .with_internal_name(key)
                  .primary_classifications

                t.attributes = {
                  id: generate_uuid(content.id, key),
                  template: false,
                  created_at: Time.zone.now,
                  updated_at: Time.zone.now,
                  name: content.properties_for(key)&.dig('label'),
                  description: content.try(key)
                }

                t.set_memoized_attribute('type_of_information', type_of_information)
              end
            }.compact
          end
        end
      end
    end
  end
end
