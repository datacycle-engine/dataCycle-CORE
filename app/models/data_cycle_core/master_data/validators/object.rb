# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for object-type data structures.
      #
      # Iterates over a schema definition and validates each field using
      # the appropriate validator based on its type. Supports nested objects
      # and object-level validations such as date ranges.
      class Object < BasicValidator
        BASIC_TYPES = {
          'object' => Validators::Object,
          'key' => Validators::Key,
          'string' => Validators::String,
          'number' => Validators::Number,
          'date' => Validators::Date,
          'datetime' => Validators::Datetime,
          'boolean' => Validators::Boolean,
          'geographic' => Validators::Geographic,
          'linked' => Validators::Linked,
          'embedded' => Validators::Embedded,
          'classification' => Validators::Classification,
          'asset' => Validators::Asset,
          'schedule' => Validators::Schedule,
          'opening_time' => Validators::Schedule,
          'collection' => Validators::Collection,
          'table' => Validators::Table,
          'oembed' => Validators::Oembed
        }.freeze

        # Returns object-level validation keys supported by this validator.
        #
        # @return [Array<String>] List of object validation identifiers
        def object_validations
          ['daterange']
        end

        # Validates a data hash against a template schema.
        #
        # Iterates over each key in the template, validates values using
        # type-specific validators, and applies object-level validations.
        #
        # @param data [Hash] Input data to validate
        # @param template_data [Hash] Schema definition for validation
        # @param strict [Boolean] Whether to enforce presence of all keys
        # @return [Hash, nil] Validation errors and warnings, or nil if data is blank
        def validate(data, template_data, strict = false)
          return if data.blank?

          data_keys = data.keys
          template_data.each do |key, key_item|
            @template_key = key

            next if !strict && data_keys.exclude?(key)
            next if key_item['type'].in?(['slug', 'timeseries'])

            unless BASIC_TYPES.include?(key_item['type'])
              (@error[:error][key] ||= []) << {
                path: 'validation.errors.object_type',
                substitutions: {
                  data: key_item,
                  type: key_item['type']
                }
              }

              next
            end

            unless key_item['type'] == 'object'
              validator_object = BASIC_TYPES[key_item['type']].new(data[key], key_item, key, strict, @content)
              merge_errors(validator_object.error) unless validator_object.nil?
              next
            end

            if key_item.key?('validations')
              key_item['validations'].each do |val_key, val_item|
                next unless object_validations.include?(val_key)

                method(val_key).call(data[key], val_item)
              end
            end

            if key_item.key?('properties')
              validator_object = BASIC_TYPES[key_item['type']].new(data[key], key_item['properties'], '', strict)
              merge_errors(validator_object.error) unless validator_object.nil?
            else
              (@error[:error][key] ||= []) << {
                path: 'validation.errors.wrong_object_type',
                substitutions: {
                  data: key_item['label']
                }
              }
            end
          end

          @error
        end

        private

        # Validates a date range defined by two fields in the object.
        #
        # Ensures both dates are valid and that the "from" date is not later than the "to" date.
        #
        # @param data_hash [Hash, nil] Object data containing date fields
        # @param template_hash [Hash] Configuration with 'from' and 'to' keys
        # @return [void]
        def daterange(data_hash, template_hash)
          data_hash = {} if data_hash.nil?

          if template_hash.blank? || template_hash['from'].blank? || template_hash['to'].blank?
            (@error[:error][@template_key] ||= []) << { path: 'validation.errors.no_fields' }
          else
            from_date = if data_hash[template_hash['from']].blank?
                          date_time('1970-01-01')
                        else
                          date_time(data_hash[template_hash['from']])
                        end

            to_date = if data_hash[template_hash['to']].blank?
                        date_time('9999-12-31')
                      else
                        date_time(data_hash[template_hash['to']])
                      end

            if from_date.nil? || to_date.nil?
              (@error[:error][@template_key] ||= []) << { path: 'validation.errors.convert_date' }
            elsif from_date > to_date
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.daterange',
                substitutions: {
                  from: from_date.to_date,
                  to: to_date.to_date
                }
              }
            end
          end
        end

        # Attempts to convert a value to a DateTime.
        #
        # @param data [Object] Input value
        # @return [DateTime, nil] Parsed DateTime or nil if conversion fails
        def date_time(data)
          data.to_datetime
        rescue StandardError
          nil
        end
      end
    end
  end
end
