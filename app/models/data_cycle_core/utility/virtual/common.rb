# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Common
        class << self
          def copy_plain(virtual_parameters:, content:, **_args)
            content.try(virtual_parameters.first)
          end

          def take_first(virtual_parameters:, content:, **_args)
            virtual_parameters.each do |virtual_key|
              val = content.try(virtual_key.to_sym)
              return val if val.present?
            end

            nil
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
        end
      end
    end
  end
end
