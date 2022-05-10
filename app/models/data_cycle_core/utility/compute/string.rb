# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module String
        class << self
          def concat(**args)
            args.dig(:computed_definition)&.dig('compute', 'parameters')&.values&.map { |item|
              item.is_a?(Hash) ? transform_string(item, args) : item
            }&.join
          end

          def transform_string(definition, args)
            case definition.dig('type')
            when 'external_source'
              args.dig(:content)&.external_source&.default_options&.dig(definition.dig('name'))
            when 'I18n'
              definition.dig('type').constantize.send(definition.dig('name'))
            when 'content'
              args.dig(:data_hash).dig(definition.dig('name')) || args.dig(:content).send(definition.dig('name'))
            when 'value'
              args.dig(:data_hash).dig('translation_type') || definition.dig('value')
            else
              raise 'Unknown type for string transformation'
            end
          end

          def number_of_characters(computed_parameters:, data_hash:, **_args)
            recursive_char_count(data_hash, computed_parameters.first.dig('paths'))&.flatten&.compact&.sum
          end

          def linked_gip_route_attribute(computed_parameters:, computed_definition:, **args)
            return args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key)) if computed_parameters.first.blank?

            # when called from UpdateComputedPropertiesJob, linked items are objects, not id-strings
            content = computed_parameters&.first&.first.is_a?(::String) ? DataCycleCore::Thing.find(computed_parameters&.first&.first) : computed_parameters&.first&.first
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
