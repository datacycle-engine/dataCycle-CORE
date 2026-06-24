# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for collection references.
      #
      # Validates arrays of UUID references pointing to WatchList or StoredFilter records.
      # Ensures correct formatting, existence, and applies collection-specific validations.
      class Collection < BasicValidator
        # Validates collection data against the provided template.
        #
        # Accepts blank values, arrays, ActiveRecord relations, or string inputs.
        # Normalizes input and validates reference integrity and constraints.
        #
        # @param data [Array<String>, ActiveRecord::Relation, String, nil] Collection references
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if blank?(data)
            return @error
          elsif data.is_a?(::Array) || data.is_a?(ActiveRecord::Relation) || data.is_a?(::String)
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

        # Normalizes and validates reference arrays for collections.
        #
        # Converts input values, applies validations, and checks referenced IDs.
        #
        # @param data [Array<Object>] Input collection references
        # @param template [Hash] Validation template
        # @return [void]
        def check_reference_array(data, template)
          converted_data = convert_data(data, template)

          if template.key?('validations')
            template['validations'].each_key do |key|
              validate_with_method(key, converted_data, template['validations'][key])
            end
          end

          return if blank?(converted_data)

          validate_references(data, converted_data.pluck(:id), template)
        end

        # Converts and validates raw collection input into model records.
        #
        # Ensures values are UUID strings and resolves them into WatchList
        # and StoredFilter records.
        #
        # @param data [Array<Object>] Input references
        # @param template [Hash] Validation template
        # @return [Array<ActiveRecord::Base>, false] Resolved records or false on error
        def convert_data(data, template)
          converted_data = data.deep_dup
          converted_data = converted_data.pluck(:id) if data.first.is_a?(ActiveRecord::Base)

          unless converted_data.all? { |d| d.is_a?(::String) && d.uuid? }
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format',
              substitutions: {
                key: converted_data.filter { |d| !d.is_a?(::String) || !d.uuid? }.join(', '),
                template: template['label']
              }
            }
            return false
          end

          DataCycleCore::WatchList.where(id: converted_data) + DataCycleCore::StoredFilter.where(id: converted_data)
        end

        # Validates that all referenced collection IDs exist.
        #
        # @param data [Array<String>] Original input IDs
        # @param collection_ids [Array<String>] Resolved IDs from DB
        # @param template [Hash] Validation template
        # @return [Boolean] True if all references are valid
        def validate_references(data, collection_ids, template)
          return true if collection_ids.size == data.size && data.to_set == collection_ids.to_set

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.not_found',
            substitutions: {
              key: (data - collection_ids).join(', '),
              template: template['label'],
              table: 'things'
            }
          }
        end

        # Warns if referenced collections do not expose an API.
        #
        # @param data [Array<WatchList, StoredFilter>] Collection objects
        # @param _value [Object] Unused validation value
        # @return [void]
        def soft_api(data, _value)
          data.each do |collection|
            next if collection.try(:api)

            (@error[:warning][@template_key] ||= []) << {
              path: 'validation.warnings.collection.no_api',
              substitutions: {
                data: collection.name
              }
            }
          end
        end
      end
    end
  end
end
