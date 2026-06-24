# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for classification values.
      #
      # Ensures that provided classification IDs are correctly formatted UUIDs
      # and exist in the configured concept tree. Supports array and string inputs
      # and applies min/max constraints on the number of references.
      class Classification < BasicValidator
        # Validates classification data against the provided template.
        #
        # Accepts blank values, arrays, or string inputs. Normalizes input and
        # validates both structure and referenced concepts.
        #
        # @param data [Array<String>, String, nil] Classification identifiers
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if blank?(data) || data.is_a?(::Array) || data.is_a?(::String)
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
          (super + ['min', 'max']).uniq
        end

        # Validates and normalizes an array of classification identifiers.
        #
        # Ensures UUID format correctness before validating existence in the
        # configured concept tree.
        #
        # @param data [Array<String>] Input classification IDs
        # @param template [Hash] Validation template
        # @return [void]
        def check_reference_array(data, template)
          run_validations(data, template)

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

        # Validates that classification IDs exist in the database and match the expected tree.
        #
        # @param data [Array<String>] UUIDs to validate
        # @param template [Hash] Validation template
        # @return [void]
        def check_references(data, template)
          uniq_data = data.uniq
          concepts = DataCycleCore::Concept.where(classification_id: uniq_data)
          concepts = concepts.includes(:concept_scheme).where(concept_scheme: { name: template['tree_label'] }) unless template['universal']
          concept_ids = concepts.pluck(:classification_id).uniq

          return if concept_ids.size == uniq_data.size && concept_ids.to_set == uniq_data.to_set

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.classification',
            substitutions: {
              key: (uniq_data - concept_ids).join(', '),
              label: template['label'],
              tree_label: template['tree_label']
            }
          }
        end

        # Validates minimum number of classifications.
        #
        # @param data [Array<String>, Object] Input values
        # @param value [Integer] Minimum required count
        # @return [void]
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

        # Validates maximum number of classifications.
        #
        # @param data [Array<String>, Object] Input values
        # @param value [Integer] Maximum allowed count
        # @return [void]
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
      end
    end
  end
end
