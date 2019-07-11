# frozen_string_literal: true

module DataCycleCore
  module Feature
    class AdvancedFilter < Base
      class << self
        def available_filters
          filters = []
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym)&.except(:enabled)&.each do |key, value|
            filters.concat(try(key.to_sym, value) || default(key.to_s, value) || [])
          end
          filters
        end

        def classification_alias_ids(value)
          if value == 'all'
            DataCycleCore::ClassificationTreeLabel.where.not(name: 'Ländercodes').pluck(:name).map do |c|
              [
                I18n.t("filter.#{c.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
                'classification_alias_ids',
                data: { name: c }
              ]
            end
          elsif value.is_a?(Array)
            value.map do |c|
              [
                I18n.t("filter.#{c.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
                'classification_alias_ids',
                data: { name: c }
              ]
            end
          else
            []
          end
        end

        def date_range(value)
          if value == 'all'
            ['created_at', 'updated_at'].map do |c|
              [
                I18n.t("filter.#{c.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
                'date_range',
                data: { name: c }
              ]
            end
          elsif value.is_a?(Hash)
            value.keys.map do |c|
              [
                I18n.t("filter.#{c.to_s.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
                'date_range',
                data: { name: c }
              ]
            end
          elsif value.is_a?(Array)
            value.map do |c|
              [
                I18n.t("filter.#{c.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
                'date_range',
                data: { name: c }
              ]
            end
          else
            []
          end
        end

        def boolean(value = [])
          value = ['duplicate_candidates'] if value == 'all'

          value.presence&.map do |c|
            [
              I18n.t("filter.#{c.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
              'boolean',
              data: { name: c }
            ]
          end || []
        end

        def default(key, value)
          if value
            [
              [
                I18n.t("filter.#{key.parameterize(separator: '_')}", default: key.capitalize, locale: DataCycleCore.ui_language),
                key,
                data: { name: key.capitalize }
              ]
            ]
          else
            []
          end
        end
      end
    end
  end
end
