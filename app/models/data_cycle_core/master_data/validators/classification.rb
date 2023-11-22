# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Classification < BasicValidator
        def keywords
          ['min', 'max', 'required']
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

          data.each do |key|
            if key.is_a?(::String)
              check_reference(key, template)
            else
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.data_array_format',
                substitutions: {
                  key:,
                  template: template['label']
                }
              }
            end
          end
        end

        def check_reference(key, template)
          return unless uuid?(key)

          where_hash = { classifications: { id: key } }
          where_hash[:classification_tree_labels] = { name: template['tree_label'] } if template['universal'].blank?
          find_classification_alias = DataCycleCore::ClassificationTree
            .joins(:classification_tree_label)
            .joins(sub_classification_alias: [classification_groups: [:classification]])
            .where(where_hash)

          return unless find_classification_alias.count < 1

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.classification',
            substitutions: {
              key:,
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
      end
    end
  end
end
