# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module String
        class << self
          def concat(computed_parameters:, computed_definition:, **_args)
            computed_parameters.values.flatten.join(computed_definition&.dig('compute', 'separator').to_s)
          end

          def value(computed_definition:, **_args)
            computed_definition.dig('compute', 'value')
          end

          def interpolate(computed_parameters:, content:, computed_definition:, **_args)
            format(computed_definition&.dig('compute', 'value').to_s, {
              locale: I18n.locale,
              created_at: content&.created_at,
              external_key: content&.external_key
            }.merge(computed_parameters.symbolize_keys))
          end

          # def transform_string(definition, args)
          #   case definition.dig('type')
          #   when 'external_source'
          #     args.dig(:content)&.external_source&.default_options&.dig(definition.dig('name'))
          #   when 'I18n'
          #     definition.dig('type').constantize.send(definition.dig('name'))
          #   when 'content'
          #     args.dig(:data_hash).dig(definition.dig('name')) || args.dig(:content).send(definition.dig('name'))
          #   when 'value'
          #     args.dig(:data_hash).dig('translation_type') || definition.dig('value')
          #   else
          #     raise 'Unknown type for string transformation'
          #   end
          # end

          def number_of_characters(computed_parameters:, data_hash:, **_args)
            recursive_char_count(data_hash, computed_parameters.first.dig('paths'))&.flatten&.compact&.sum
          end

          def linked_gip_route_attribute(computed_parameters:, computed_definition:, **_args)
            content = DataCycleCore::Thing.find_by(id: computed_parameters.values.first)

            content&.send(computed_definition&.dig('compute', 'linked_attribute').to_s)
          end

          private

          def recursive_char_count(data, parameters)
            return if parameters.blank? || data.blank?

            parameters.map do |parameter|
              if parameter.is_a?(::Hash)
                parameter.map do |k, v|
                  data.dig(k)&.map { |s| recursive_char_count(s, v) }
                end
              else
                ActionController::Base.helpers.strip_tags(data.dig(parameter).to_s).size
              end
            end
          end
        end
      end
    end
  end
end
