# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module TransformationUtilities
          def resolve_attribute_path(data, path)
            path = Array.wrap(path)

            path.reduce(data) do |partial_data, key|
              if partial_data.is_a?(Hash)
                partial_data[key]
              elsif partial_data.is_a?(Array)
                partial_data.flatten.pluck(key)
              end
            end
          end

          def transformation_with_args(transformation_method:, utility_object:, config: {})
            transform_opts = transformation_args(transformation_method:, utility_object:, config:)
            transform_kwargs = transformation_keyword_args(transformation_method:, utility_object:, config:)

            transformation_method.call(*transform_opts, **transform_kwargs)
          end

          private

          def transformation_config(config:)
            transformation_config = (config&.deep_dup || {}).with_indifferent_access
            transformation_config.merge!(transformation_config.delete(:transformation_config) || {}) if transformation_config.key?(:transformation_config)
            transformation_config
          end

          def transformation_args(transformation_method:, utility_object:, config:)
            transform_opts = []
            transform_params = transformation_method.parameters.select { |param| param[0].in?([:req, :opt]) }

            if transform_params.dig(0, 1).to_s.end_with?('_id')
              transform_opts << utility_object.external_source.id
            elsif transform_params.dig(0, 1).present?
              transform_opts << utility_object.external_source
            end

            transform_opts << transformation_config(config:) if transform_params.dig(1, 1).in?([:options, :config])

            transform_opts
          end

          def transformation_keyword_args(transformation_method:, utility_object:, config:)
            transform_kwargs = {}
            transform_keyreq_params = transformation_method.parameters.select { |param| param[0].in?([:key, :keyreq]) }

            transform_keyreq_params.each do |param|
              case param[1]
              when :external_source_id
                transform_kwargs[param[1]] = utility_object.external_source.id
              when :external_source
                transform_kwargs[param[1]] = utility_object.external_source
              when :config
                transform_kwargs[param[1]] = transformation_config(config:)
              end
            end

            transform_kwargs
          end
        end
      end
    end
  end
end
