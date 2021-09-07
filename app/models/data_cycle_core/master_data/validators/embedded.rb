# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Embedded < BasicValidator
        def keywords
          ['min', 'max', 'classifications']
        end

        def validate(data, template, _strict = false)
          if blank?(data)
            # ignore
          elsif data.is_a?(::Array)
            check_data_array(data, template)
          elsif data.is_a?(::Hash)
            check_data_array([data], template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format_embedded',
              substitutions: {
                data: data,
                template: template['label']
              }
            }
          end

          @error
        end

        private

        def check_data_array(data, template)
          # validate given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(data, template['validations'][key]) if keywords.include?(key)
            end
          end

          # validate references
          embedded_template = DataCycleCore::Thing
            .find_by(template: true, template_name: template['template_name'])
          if template.blank? || embedded_template.blank?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.no_template',
              substitutions: {
                name: 'things'
              }
            }

            return
          end
          data.each do |item|
            next if item.empty?
            if item.is_a?(::Hash)
              validator_object = DataCycleCore::MasterData::ValidateData.new
              merge_errors(validator_object.validate(item, embedded_template.schema))
            else
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.data_format_embedded',
                substitutions: {
                  data: data,
                  template: template['label']
                }
              }
            end
          end
        end

        def classifications(values, _template_hash)
          return if values.blank? || DataCycleCore.features.dig(:publication_schedule, :classification_keys).blank?

          values = values.dc_deep_dup
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.classification_conflict' } if values
            .each { |d| d['id'] = SecureRandom.uuid if d['id'].blank? }
            .map { |x|
              values
                .select do |y|
                (x != y) && DataCycleCore.features
                  .dig(:publication_schedule, :classification_keys)
                  .map { |z| x[z].present? && y[z].present? ? (x[z] & y[z]) : [] }
                  .all?(&:present?)
              end
            }
            .flatten
            .present?
        end

        # validate nil,"",[],[nil],[""],[{}] as blank.
        def blank?(data)
          return true if data.blank?
          if data.is_a?(::Array)
            return true if data.length == 1 && data[0].blank?
          end
          false
        end

        def min(data, value)
          return unless data.size < value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_ref',
            substitutions: {
              data: data.size,
              value: value
            }
          }
        end

        def max(data, value)
          return unless data.size > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data.size,
              value: value
            }
          }
        end
      end
    end
  end
end
