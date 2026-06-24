# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for schedule data structures.
      #
      # Validates arrays of schedule entries, ensuring structural correctness,
      # valid date/time formats, recurrence rules, and duration constraints.
      class Schedule < BasicValidator
        # Validates schedule data against the provided template.
        #
        # Handles blank values, validates array structure, applies template-based
        # validations, and performs detailed checks on each schedule entry.
        #
        # @param data [Array<Hash>, nil] Schedule data to validate
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if data.blank?
            required(data, template.dig('validations', 'required')) if template.dig('validations', 'required')
          elsif data.is_a?(::Array)
            if template.key?('validations')
              template['validations'].each_key do |key|
                validate_with_method(key, data, template['validations'][key])
              end
            end

            check_data_array(data, template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.schedule.general',
              substitutions: {
                data:,
                template: template['label']
              }
            }
          end

          @error
        end

        # Performs detailed validation of each schedule entry in the array.
        #
        # Iterates over each item and validates specific fields such as IDs,
        # relations, timestamps, recurrence rules, and date arrays.
        #
        # @param data [Array<Hash>] Schedule entries
        # @param template [Hash] Validation template
        # @return [void]
        def check_data_array(data, template)
          data.each do |data_item|
            data_item.deep_symbolize_keys.each do |key, value|
              case key
              when :thing_id
                unless uuid?(value)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.thing_id',
                    substitutions: {
                      data:,
                      template: template['label']
                    }
                  }
                end
              when :relation
                if value.blank?
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.relation',
                    substitutions: {
                      data:,
                      template: template['label']
                    }
                  }
                end
              when :start_time, :end_time
                unless hash_value_with_zone?(value)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.time',
                    substitutions: {
                      data:,
                      template: template['label']
                    }
                  }
                end
              when :rdate, :exdate
                unless date_time_array?(value)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.date_time_array',
                    substitutions: {
                      data:,
                      template: template['label']
                    }
                  }
                end
              when :rrule
                unless rrule?(value&.first)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.rrule',
                    substitutions: {
                      data:,
                      template: template['label']
                    }
                  }
                end
              end
            end
          end
        end

        # Validates that a hash contains a time and a valid timezone.
        #
        # @param data [Hash] Hash containing :time and :zone keys
        # @return [Boolean] True if valid, false otherwise
        def hash_value_with_zone?(data)
          return false unless data.is_a?(::Hash)
          return false unless data.keys.sort == [:time, :zone]
          return false unless date_time?(data[:time])
          return false if Time.find_zone(data[:zone]).blank?

          true
        end

        # Validates whether schedule dates produce a valid schedule instance.
        #
        # Adds an error or warning if the schedule is invalid.
        #
        # @param schedule_hash [Hash] Schedule definition
        # @param error_type [Symbol] :error or :warning
        # @return [void]
        def check_valid_dates(schedule_hash, error_type = :error)
          schedule = DataCycleCore::Schedule.new.from_hash(schedule_hash)&.schedule_object

          return if schedule.nil?
          return if schedule.first.present?

          (@error[error_type][@template_key] ||= []) << {
            path: 'validation.errors.schedule.invalid',
            substitutions: {
              data: {
                method: 'l',
                value: schedule&.start_time,
                substitutions: {
                  format: :edit
                }
              }
            }
          }
        end

        private

        # Validates schedule dates strictly.
        #
        # @param data [Array<Hash>] Schedule entries
        # @param value [Boolean] Whether validation is enabled
        # @return [void]
        def valid_dates(data, value)
          return unless value

          data.each do |data_item|
            check_valid_dates(data_item, :error)
          end
        end

        # Validates schedule dates softly (warning level).
        #
        # @param data [Array<Hash>] Schedule entries
        # @param value [Boolean] Whether validation is enabled
        # @return [void]
        def soft_valid_dates(data, value)
          return unless value

          data.each do |data_item|
            check_valid_dates(data_item, :warning)
          end
        end

        # Ensures schedule has a closed range (e.g., an end condition).
        #
        # @param schedule_hash [Hash] Schedule definition
        # @return [void]
        def check_closed_range(schedule_hash)
          validation_hash = schedule_hash.with_indifferent_access

          return if validation_hash.dig('rrules', 0, 'until').present? || (
            (
              validation_hash.dig('rrules', 0, 'rule_type') == 'IceCube::SingleOccurrenceRule' ||
              validation_hash.dig('rrules', 0, 'rule_type').blank?
            ) && validation_hash.dig('end_time', 'time').present?
          )

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.schedule.until_missing',
            substitutions: {
              data: {
                method: 'l',
                value: validation_hash.dig('start_time', 'time')&.in_time_zone,
                substitutions: {
                  format: :edit
                }
              }
            }
          }
        end

        # Validates closed range requirement for schedules.
        #
        # @param data [Array<Hash>] Schedule entries
        # @param value [Boolean] Whether validation is enabled
        # @return [void]
        def closed_range(data, value)
          return unless value

          data.each do |data_item|
            check_closed_range(data_item)
          end
        end

        # Validates that all elements in an array are valid date-time values.
        #
        # @param data [Array<Object>] Array of date-time values
        # @return [Boolean] True if all values are valid, false otherwise
        def date_time_array?(data)
          return false unless data.is_a?(::Array)

          data.each do |item|
            return false unless date_time?(item)
          end

          true
        end

        # Validates recurrence rule structure.
        #
        # @param data [Hash, nil] Recurrence rule definition
        # @return [Boolean] True if valid, false otherwise
        def rrule?(data)
          return true if data.blank?
          return false unless data.is_a?(::Hash)

          IceCube::Rule.from_hash(data)
          true
        rescue ArgumentError
          false
        end

        # Validates whether a value can be parsed as a date-time.
        #
        # @param data [Object] Value to validate
        # @return [Boolean] True if valid date-time, false otherwise
        def date_time?(data)
          data.in_time_zone
          true
        rescue StandardError
          false
        end

        # Validates that schedule duration does not exceed a maximum value.
        #
        # @param schedule_hash [Hash] Schedule definition
        # @param value [String] Maximum duration string
        # @return [void]
        def check_valid_duration(schedule_hash, value)
          schedule = DataCycleCore::Schedule.new.from_hash(schedule_hash)

          return if schedule.nil? || schedule.duration.nil? || schedule.duration.zero?

          max = ActiveSupport::Duration.parse(value)

          return if schedule.duration <= max

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.warnings.schedule.duration_too_long',
            substitutions: {
              data: {
                method: 'l',
                value: schedule&.dtstart,
                substitutions: {
                  format: :edit
                }
              },
              max: {
                method: 'distance_of_time_in_words',
                value: [
                  Time.zone.now,
                  Time.zone.now + max
                ]
              }
            }
          }
        end

        # Applies soft maximum duration validation to schedule entries.
        #
        # @param data [Array<Hash>] Schedule entries
        # @param value [String] Maximum duration
        # @return [void]
        def soft_max_duration(data, value)
          return unless value

          data.each do |data_item|
            check_valid_duration(data_item, value)
          end
        end

        # Adds an error if the schedule is required but blank.
        #
        # @param data [Object] Schedule data
        # @param value [Boolean] Whether required validation is enabled
        # @return [void]
        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end

        # Validates that the schedule end date does not exceed a maximum date.
        #
        # @param data [Array<Hash>] Schedule entries
        # @param value [String] Maximum date expression
        # @return [void]
        def soft_max_date(data, value)
          max_value = ERB.new(value.to_s).result(binding).in_time_zone.to_date

          data.each do |data_item|
            validation_hash = data_item.with_indifferent_access

            next if validation_hash.dig('rrules', 0, 'until').blank? ||
                    validation_hash.dig('rrules', 0, 'until').in_time_zone <= max_value

            (@error[:warning][@template_key] ||= []) << {
              path: 'validation.errors.schedule.until_too_far',
              substitutions: {
                data: {
                  method: 'l',
                  value: validation_hash.dig('start_time', 'time')&.in_time_zone,
                  substitutions: {
                    format: :edit
                  }
                },
                max: {
                  method: 'l',
                  value: max_value,
                  substitutions: {
                    format: :edit
                  }
                }
              }
            }
          end
        end
      end
    end
  end
end
