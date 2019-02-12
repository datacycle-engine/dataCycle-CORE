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

        def self.operations_to_opening_hours(data_hash, attribute, operations)
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
            # Wochentage
            days = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
              .where(classification_tree_labels: { name: 'Wochentage' }).each_with_object({}) do |value, hash|
                hash[value.name] = value.id
              end

            case operation_condition
            when 401
              opening_hours_days = days.values
            when 402
              opening_hours_days = [days.dig('Samstag'), days.dig('Sonntag')]
            when 404
              opening_hours_days = [days.dig('Freitag'), days.dig('Samstag'), days.dig('Sonntag')]
            else
              data_hash[attribute] = []
              return data_hash
            end

            data_hash[attribute] = [
              {
                'description' => data_hash.dig(operations, 'operationRemarks', '#cdata-section'),
                'day_of_week' => opening_hours_days,
                'time' => [
                  {
                    'opens' => data_hash.dig(operations, 'operationStart', 'text'),
                    'closes' => data_hash.dig(operations, 'operationEnd', 'text')
                  }
                ]
              }
            ]
          end
          data_hash
        end

        def self.get_title_from_locale(data_hash, attribute, type, locale)
          return data_hash if data_hash.blank?
          attribute_name = type.call(data_hash)
          data_hash[attribute] = I18n.t("external_sources.bergfex.snow_report.type.#{attribute_name}", locale: locale)
          data_hash
        end
      end
    end
  end
end
