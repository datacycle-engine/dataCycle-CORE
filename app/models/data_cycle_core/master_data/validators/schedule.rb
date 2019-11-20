# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Schedule < BasicValidator
        # TODO: dummy evaluator for now
        def validate(data, template)
          if data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_language)
          elsif data.is_a?(::Hash)
            data.deep_symbolize_keys.each do |key, value|
              case key
              when :start_time, :end_time
                (@error[:error][@template_key] ||= []) << I18n.t(:time, scope: [:validation, :errors, :schedule], data: data, template: template['label'], locale: DataCycleCore.ui_language) unless hash_value_with_zone?(value)
              when :rdate, :exdate
                (@error[:error][@template_key] ||= []) << I18n.t(:date_time_array, scope: [:validation, :errors, :schedule], data: data, template: template['label'], locale: DataCycleCore.ui_language) unless date_time_array?(value)
              when :rrule
                (@error[:error][@template_key] ||= []) << I18n.t(:rrule, scope: [:validation, :errors, :schedule], data: data, template: template['label'], locale: DataCycleCore.ui_language) unless rrule?(value&.first)
              end
            end
          elsif data.is_a?(::DataCycleCore::Schedule) || data.is_a?(::IceCube::Schedule)
            # all ok
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:general, scope: [:validation, :errors, :schedule], data: data, template: template['label'], locale: DataCycleCore.ui_language)
          end
          @error
        end

        def hash_value_with_zone?(data)
          return false unless data.is_a?(::Hash)
          return false unless data.keys.sort == [:time, :zone]
          return false unless date_time?(data[:time])
          return false if Time.find_zone(data[:zone]).blank?
          true
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
