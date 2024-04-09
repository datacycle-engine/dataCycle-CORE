# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Linked < BasicValidator
        def keywords
          ['min', 'max', 'required', 'soft_required', 'soft_min', 'soft_max']
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
                data:,
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

          validate_references(converted_data, template)
        end

        def validate_references(data, template)
          unless data.all? { |d| d.is_a?(::String) && d.uuid? }
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format',
              substitutions: {
                key: data.filter { |d| !d.is_a?(::String) || !d.uuid? }.join(', '),
                template: template['label']
              }
            }
            return false
          end

          linked_ids = DataCycleCore::Thing.where(id: data).ids

          return true if linked_ids.size == data.size && data.to_set == linked_ids.to_set

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.not_found',
            substitutions: {
              key: (data - linked_ids).join(', '),
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
              value:
            }
          }
        end

        def soft_min(data, value)
          return unless data&.size.to_i < value

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.errors.min_ref',
            substitutions: {
              data: data&.size.to_i,
              value:
            }
          }
        end

        def max(data, value)
          return unless data&.size.to_i > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data&.size.to_i,
              value:
            }
          }
        end

        def soft_max(data, value)
          return unless data&.size.to_i > value

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data&.size.to_i,
              value:
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
