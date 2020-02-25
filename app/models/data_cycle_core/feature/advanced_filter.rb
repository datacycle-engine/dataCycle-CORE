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
          return [] unless value

          DataCycleCore::ClassificationTreeLabel.where('? = ANY(classification_tree_labels.visibility)', 'filter').pluck(:name).map do |c|
            [
              I18n.t("filter.#{c.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
              'classification_alias_ids',
              data: { name: c }
            ]
          end
        end

        def geo_filter(value)
          if value.is_a?(Hash)
            value_arr = []
            value.each do |k, v|
              if v.is_a?(Array)
                v.map do |c|
                  value_arr << [
                    I18n.t("filter.#{c.parameterize(separator: '_')}", default: c, locale: DataCycleCore.ui_language),
                    'geo_filter',
                    data: { name: c, advancedType: k }
                  ]
                end
              elsif v
                value_arr << [
                  I18n.t("filter.#{k.parameterize(separator: '_')}", default: k.capitalize, locale: DataCycleCore.ui_language),
                  'geo_filter',
                  data: { name: k, advancedType: k }
                ]
              end
            end
            value_arr
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
          return [] unless value

          [
            [
              I18n.t("filter.#{key.parameterize(separator: '_')}", default: key.capitalize, locale: DataCycleCore.ui_language),
              key,
              data: { name: key.capitalize }
            ]
          ]
        end

        def advanced_attributes(value)
          return [] unless value
          value.map do |k, v|
            [
              I18n.t("filter.#{k.parameterize(separator: '_')}", default: k, locale: DataCycleCore.ui_language),
              'advanced_attributes',
              data: { name: k, advancedType: v.dig('type') }
            ]
          end
        end
      end
    end
  end
end
