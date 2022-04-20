# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Schedule < BasicValidator
        def keywords
          ['valid_dates', 'closed_range', 'soft_max_duration']
        end

        def validate(data, template, _strict = false)
          if data.blank?
            # ignore
          elsif data.is_a?(::Array)
            if template.key?('validations')
              template['validations'].each_key do |key|
                method(key).call(data, template['validations'][key]) if keywords.include?(key)
              end
            end

            check_data_array(data, template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.schedule.general',
              substitutions: {
                data: data,
                template: template['label']
              }
            }
          end

          @error
        end

        def check_data_array(data, template)
          data.each do |data_item|
            data_item.deep_symbolize_keys.each do |key, value|
              case key
              when :thing_id
                unless uuid?(value)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.thing_id',
                    substitutions: {
                      data: data,
                      template: template['label']
                    }
                  }
                end
              when :relation
                if value.blank?
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.relation',
                    substitutions: {
                      data: data,
                      template: template['label']
                    }
                  }
                end
              when :start_time, :end_time
                unless hash_value_with_zone?(value)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.time',
                    substitutions: {
                      data: data,
                      template: template['label']
                    }
                  }
                end
              when :rdate, :exdate
                unless date_time_array?(value)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.date_time_array',
                    substitutions: {
                      data: data,
                      template: template['label']
                    }
                  }
                end
              when :rrule
                unless rrule?(value&.first)
                  (@error[:error][@template_key] ||= []) << {
                    path: 'validation.errors.schedule.rrule',
                    substitutions: {
                      data: data,
                      template: template['label']
                    }
                  }
                end
              end
            end
          end
        end

        def hash_value_with_zone?(data)
          return false unless data.is_a?(::Hash)
          return false unless data.keys.sort == [:time, :zone]
          return false unless date_time?(data[:time])
          return false if Time.find_zone(data[:zone]).blank?
          true
        end

        def check_valid_dates(schedule_hash)
          schedule = DataCycleCore::Schedule.new.from_hash(schedule_hash)&.schedule_object

          return if schedule.nil?

          return if schedule.first.present?

          (@error[:error][@template_key] ||= []) << {
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

        def valid_dates(data, value)
          return unless value

          data.each do |data_item|
            check_valid_dates(data_item)
          end
        end

        def check_closed_range(schedule_hash)
          return if schedule_hash.dig('rrules', 0, 'until').present?

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.schedule.until_missing',
            substitutions: {
              data: {
                method: 'l',
                value: schedule_hash.dig('start_time', 'time')&.in_time_zone,
                substitutions: {
                  format: :edit
                }
              }
            }
          }
        end

        def closed_range(data, value)
          return unless value

          data.each do |data_item|
            check_closed_range(data_item)
          end
        end

        def date_time_array?(data)
          false unless data.is_a?(::Array)
          data.each do |item|
            return false unless date_time?(item)
          end
          true
        end

        def rrule?(data)
          return true if data.blank?
          return false unless data.is_a?(::Hash)
          IceCube::Rule.from_hash(data)
          true
        rescue ArgumentError
          false
        end

        def date_time?(data)
          data.in_time_zone
          true
        rescue StandardError
          false
        end

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

        def soft_max_duration(data, value)
          return unless value

          data.each do |data_item|
            check_valid_duration(data_item, value)
          end
        end
      end
    end
  end
end
