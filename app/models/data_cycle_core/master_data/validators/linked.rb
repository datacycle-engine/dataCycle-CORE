# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Linked < BasicValidator
        def keywords
          ['min', 'max', 'required', 'soft_min', 'soft_max']
        end

        def validate(data, template, _strict = false)
          if blank?(data)
            check_reference_array(data, template)
          elsif data.is_a?(::Array) || data.is_a?(ActiveRecord::Relation)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data], template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_type',
              substitutions: {
                data: data,
                template: template['label']
              }
            }
          end

          @error
        end

        private

        def check_reference_array(data, template)
          converted_data = data.deep_dup
          converted_data = converted_data.ids if data.is_a?(ActiveRecord::Relation)
          # validate given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(converted_data, template['validations'][key]) if keywords.include?(key)
            end
          end

          # validate references
          return if blank?(converted_data)

          converted_data.each do |key|
            validate_reference(key, template)
          end
        end

        def validate_reference(key, template)
          if key.is_a?(::String)
            check_reference(key, template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format',
              substitutions: {
                key: key,
                template: template['label']
              }
            }
          end
        end

        def check_reference(key, template)
          return unless uuid?(key)

          data_set = DataCycleCore::Thing.where(id: key)

          return unless data_set.count < 1

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.not_found',
            substitutions: {
              key: key,
              template: template['label'],
              table: 'things'
            }
          }
        end

        def min(data, value)
          return unless data&.size.to_i < value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_ref',
            substitutions: {
              data: data&.size.to_i,
              value: value
            }
          }
        end

        def soft_min(data, value)
          return unless data&.size.to_i < value

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.errors.min_ref',
            substitutions: {
              data: data&.size.to_i,
              value: value
            }
          }
        end

        def max(data, value)
          return unless data&.size.to_i > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data&.size.to_i,
              value: value
            }
          }
        end

        def soft_max(data, value)
          return unless data&.size.to_i > value

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data&.size.to_i,
              value: value
            }
          }
        end

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end

        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end
      end
    end
  end
end
