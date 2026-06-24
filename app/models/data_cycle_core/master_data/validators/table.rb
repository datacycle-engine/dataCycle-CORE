# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for table-like data structures.
      #
      # Ensures that the input is a valid table (array of arrays), validates
      # structural consistency (e.g., equal column sizes), and applies additional
      # validation rules defined in the template.
      class Table < BasicValidator
        # Validates table data against the provided template.
        #
        # Checks whether the data is a valid table structure and performs
        # row consistency validation before executing configured validations.
        # Adds an error if the data type is invalid.
        #
        # @param data [Array<Array<Object>>, nil] The table data to validate
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if valid_table_data?(data)
            validate_table_data(data)

            run_validations(data, template)
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

        # Validates structural consistency of table rows.
        #
        # Ensures that all rows have the same number of columns.
        # Adds an error for each row that deviates from the expected size.
        #
        # @param data [Array<Array<Object>>] Table data
        # @return [void]
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

        # Checks whether the provided data is a valid table structure.
        #
        # A valid table is either nil or an array of arrays.
        #
        # @param data [Object] Input data
        # @return [Boolean] True if valid table structure, false otherwise
        def valid_table_data?(data)
          return true if data.nil?

          data.is_a?(::Array) && data.all?(::Array)
        end

        # Adds an error if the table is required but blank.
        #
        # @param data [Array<Array<Object>>, nil] Table data
        # @param value [Boolean] Whether the field is required
        # @return [void]
        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && DataHashService.deep_blank?(data)
        end

        # Adds a warning if the table is soft-required but blank.
        #
        # @param data [Array<Array<Object>>, nil] Table data
        # @param value [Boolean] Whether the field is soft-required
        # @return [void]
        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && DataHashService.deep_blank?(data)
        end
      end
    end
  end
end
