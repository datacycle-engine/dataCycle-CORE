# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Classification < BasicValidator
        def keywords
          ['min', 'max', 'required', 'soft_required']
        end

        def validate(data, template, _strict = false)
          if blank?(data)
            check_reference_array(data, template)
          elsif data.is_a?(::Array)
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
          # check given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(data, template['validations'][key]) if keywords.include?(key)
            end
          end

          # validate references themself
          return if blank?(data)

          uuids = []

          data.each do |key|
            next uuids.push(key) if key.is_a?(::String) && key.uuid?

            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_array_format',
              substitutions: {
                key:,
                template: template['label']
              }
            }
          end

          check_references(uuids, template)
        end

        def check_references(data, template)
          concepts = DataCycleCore::Concept.where(classification_id: data)
          concepts = concepts.includes(:concept_scheme).where(concept_scheme: { name: template['tree_label'] }) unless template['universal']
          concept_ids = concepts.pluck(:classification_id).uniq

          return if concept_ids.size == data.size && concept_ids.to_set == data.to_set

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.classification',
            substitutions: {
              key: (data - concept_ids).join(', '),
              label: template['label'],
              tree_label: template['tree_label']
            }
          }
        end

        def min(data, value)
          return unless Array.wrap(data).size < value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_ref',
            substitutions: {
              data: Array.wrap(data).size,
              value:
            }
          }
        end

        def max(data, value)
          return unless data.present? && data.size > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data.size,
              value:
            }
          }
        end

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end

        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && blank?(data)
        end
      end
    end
  end
end
