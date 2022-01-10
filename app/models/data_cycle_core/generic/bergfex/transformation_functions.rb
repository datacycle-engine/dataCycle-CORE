# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.operations_to_opening_hours(data_hash, external_source_id, attribute, operations)
          return data_hash if data_hash.blank?

          if data_hash.dig(operations).blank?
            data_hash[attribute] = []
          else
            operation_condition = data_hash.dig(operations, 'operation', 'id')&.to_i
            # conditions
            # 400 - keine Meldung
            # 401 - täglich
            # 402 - nur am Wochenende
            # 403 - geschlossen
            # 404 - Freitag bis Sonntag
            # day_of_week

            case operation_condition
            when 401
              opening_hours_days = (0...7).to_a
              holidays = true
            when 402
              opening_hours_days = [6, 0]
            when 404
              opening_hours_days = [5, 6, 0]
            else
              data_hash[attribute] = []
              return data_hash
            end

            data_hash[attribute] = DataCycleCore::Generic::Common::OpeningHours.parse_opening_times({
              'TimeFrom' => data_hash.dig(operations, 'operationStart', 'text'),
              'TimeTo' => data_hash.dig(operations, 'operationEnd', 'text'),
              'Holidays' => holidays,
              'WeekDays' => opening_hours_days
            }, external_source_id, data_hash['external_key'])

            if data_hash.dig(operations, 'operationRemarks', '#cdata-section').present?
              data_hash['opening_hours_description'] = [{
                description: data_hash.dig(operations, 'operationRemarks', '#cdata-section'),
                validity_schedule: [{
                  start_time: {
                    time: Time.zone.now.beginning_of_day.to_s,
                    zone: Time.zone.name
                  },
                  rrules: [{
                    rule_type: 'IceCube::WeeklyRule',
                    validations: {
                      day: opening_hours_days
                    }
                  }]
                }.with_indifferent_access]
              }]
            else
              data_hash['opening_hours_description'] = []
            end
          end
          data_hash
        end

        def self.operation_to_status(data_hash, attribute, operation)
          return data_hash if data_hash.blank?

          if data_hash.dig(operation).blank?
            data_hash[attribute] = []
          else
            operation_condition = data_hash.dig('operation', 'id')&.to_i
            # conditions
            # 400 - keine Meldung
            # 401 - täglich
            # 402 - nur am Wochenende
            # 403 - geschlossen
            # 404 - Freitag bis Sonntag
            operation_string =
              case operation_condition
              when 400
                'odta:NoInformation'
              when 401
                'odta:Open'
              when 402, 404
                'odta:WeekendOnly'
              when 403
                'odta:Closed'
              else
                data_hash[attribute] = []
                return data_hash
              end

            data_hash[attribute] = Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('odta:OpeningStatus', operation_string))
          end
          data_hash
        end

        def self.get_title_from_locale(data_hash, attribute, type, locale)
          return data_hash if data_hash.blank?
          attribute_name = type.call(data_hash)
          data_hash[attribute] = I18n.t("external_sources.bergfex.snow_report.type.#{attribute_name}", locale: locale)
          data_hash
        end

        def self.parse_condition_snow(hash, attribute, tree_label)
          return hash if hash['conditionSnow'].blank? || hash.dig('conditionSnow', 'text').blank?

          names = hash.dig('conditionSnow', 'text').split('-')
          if I18n.locale == :en
            names = names.map { |n| n.in?(['spring', 'snow']) ? 'spring snow' : n }
            names = ['icy', 'hard'] if names.in?(['iron hard', 'hard iron'])
            names = ['soft', 'wet'] if names.in?(['soft wet'])
          end

          hash[attribute] = DataCycleCore::ClassificationAlias.for_tree(tree_label).with_name(names).map(&:primary_classification)&.map(&:id)
          hash
        end
      end
    end
  end
end
