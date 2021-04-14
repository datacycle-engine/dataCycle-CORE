# frozen_string_literal: true

module DataCycleCore
  module Feature
    class AdvancedFilter < Base
      class << self
        def available_filters
          filters = []
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym)&.except(:enabled, :config)&.each do |key, value|
            filters.concat(try(key.to_sym, value) || default(key.to_s, value) || [])
          end
          filters
        end

        def advanced_attribute_classification_tree_label(specific_type)
          configuration.dig('advanced_attributes', specific_type, 'tree_label')
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

        def relation_filter(value)
          return [] unless value.is_a?(Hash)
          value.map do |k, v|
            [
              I18n.t("filter.#{k.parameterize(separator: '_')}", default: k.capitalize, locale: DataCycleCore.ui_language),
              'relation_filter',
              data: { name: k, advancedType: v }
            ]
          end
        end

        def union_filter_ids(value)
          return [] unless value
          [
            [
              I18n.t('filter.union_filter_ids', collections: DataCycleCore::WatchList.model_name.human(count: 2, locale: DataCycleCore.ui_language), default: 'union_filter_ids'.capitalize, locale: DataCycleCore.ui_language),
              'union_filter_ids',
              data: { name: 'union_filter_ids'.capitalize }
            ]
          ]
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

        def inactive_things(value)
          return [] unless value
          value.map do |k, _v|
            [
              I18n.t("filter.in_schedule_types.#{k.parameterize(separator: '_')}", default: k, locale: DataCycleCore.ui_language),
              'inactive_things',
              data: { name: k }
            ]
          end
        end

        def in_schedule(value)
          return [] unless value
          value.map do |k, _v|
            [
              I18n.t("filter.in_schedule_types.#{k.parameterize(separator: '_')}", default: k, locale: DataCycleCore.ui_language),
              'in_schedule',
              data: { name: k }
            ]
          end
        end

        def validity_period(value)
          return [] unless value
          value.map do |k, _v|
            [
              I18n.t("filter.in_schedule_types.#{k.parameterize(separator: '_')}", default: k, locale: DataCycleCore.ui_language),
              'validity_period',
              data: { name: k }
            ]
          end
        end

        def always_visible?
          !!configuration.dig(:config, :visible)
        end
      end
    end
  end
end
