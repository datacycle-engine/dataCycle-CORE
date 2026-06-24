# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for linked references to other entities (e.g., Things).
      #
      # Validates that provided references are in the correct format (UUIDs),
      # checks existence in the database, and applies size-based constraints.
      class Linked < BasicValidator
        # Validates linked data against the provided template.
        #
        # Accepts arrays, ActiveRecord relations, strings, or blank values.
        # Converts input into an array and validates references and constraints.
        #
        # @param data [Array<String>, ActiveRecord::Relation, String, nil] Input references
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if blank?(data) || data.is_a?(::Array) || data.is_a?(ActiveRecord::Relation) || data.is_a?(::String)
            check_reference_array(Array.wrap(data), template)
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

        # Extends validations that are allowed on blank values.
        #
        # @return [Array<String>] List of validation keys allowed on blank data
        def validations_on_blank
          (super + ['min', 'soft_min', 'max', 'soft_max']).uniq
        end

        # Normalizes and validates a reference array.
        #
        # Converts ActiveRecord relations to ID arrays, runs configured validations,
        # and validates the existence and format of referenced IDs.
        #
        # @param data [Array<Object>] Input references
        # @param template [Hash] Validation template
        # @return [void]
        def check_reference_array(data, template)
          converted_data = data.deep_dup
          converted_data = converted_data.pluck(:id) if data.is_a?(ActiveRecord::Relation)

          run_validations(data, template)

          return if blank?(converted_data)

          validate_references(converted_data, template)
        end

        # Validates that all references are valid UUIDs and exist in the database.
        #
        # Adds errors for invalid formats or missing records.
        #
        # @param data [Array<String>] Array of reference IDs
        # @param template [Hash] Validation template
        # @return [Boolean, nil] True if valid, false or nil otherwise
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

          linked_ids = DataCycleCore::Thing.where(id: data).pluck(:id)

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

        # Validates minimum number of references (error level).
        #
        # @param data [Array<Object>] Reference array
        # @param value [Integer] Minimum required size
        # @return [void]
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

        # Validates minimum number of references (warning level).
        #
        # @param data [Array<Object>] Reference array
        # @param value [Integer] Minimum required size
        # @return [void]
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

        # Validates maximum number of references (error level).
        #
        # @param data [Array<Object>] Reference array
        # @param value [Integer] Maximum allowed size
        # @return [void]
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

        # Validates maximum number of references (warning level).
        #
        # @param data [Array<Object>] Reference array
        # @param value [Integer] Maximum allowed size
        # @return [void]
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
      end
    end
  end
end
