# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Schedule < BasicValidator
        def keywords
          ['valid_dates', 'closed_range']
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

          if schedule.first.blank?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.schedule.invalid',
              substitutions: {
                data: {
                  localization_method: 'l',
                  localization_value: schedule&.start_time,
                  substitutions: {
                    format: :edit
                  }
                },
                template: template['label']
              }
            }
          end
        end

        def valid_dates(data, value)
          return unless value

          data.each do |data_item|
            check_valid_dates(data_item)
          end
        end

        def check_closed_range(schedule_hash)
          if schedule_hash.dig('rrules', 0, 'until').blank?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.schedule.until_missing',
              substitutions: {
                data: {
                  localization_method: 'l',
                  localization_value: schedule_hash.dig('start_time', 'time')&.in_time_zone,
                  substitutions: {
                    format: :edit
                  }
                },
                template: template['label']
              }
            }
          end
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
            return false unless item.date_time?
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
      end
    end
  end
end
