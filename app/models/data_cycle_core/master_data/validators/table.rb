# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Table < BasicValidator
        def validate(data, template, _strict = false)
          if valid_table_data?(data)
            validate_table_data(data)

            if template.key?('validations')
              template['validations'].each_key do |key|
                validate_with_method(key, data, template['validations'][key])
              end
            end
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.table',
              substitutions: {
                template: data.class.name,
                label: template['label']
              }
            }
          end

          @error
        end

        private

        def validate_table_data(data)
          return if DataHashService.deep_blank?(data)

          column_count = data.first.size

          data.each do |row|
            next if row.size == column_count

            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.table_row_wrong_size',
              row:
            }
          end
        end

        def valid_table_data?(data)
          return true if data.nil?

          data.is_a?(::Array) && data.all?(::Array)
        end

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && DataHashService.deep_blank?(data)
        end

        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && DataHashService.deep_blank?(data)
        end
      end
    end
  end
end
