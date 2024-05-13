# frozen_string_literal: true

module DataCycleCore
  module Feature
    class AdvancedFilter < Base
      class << self
        def available_filters(user, view_type)
          return [] unless enabled? && !user.nil?

          filters = []
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym)&.except(:enabled, :config)&.each do |key, value|
            filters.concat(try(key.to_sym, user, value) || default(user, key.to_s, value) || [])
          end

          filters
            .select { |k, v, data| user&.can?(:advanced_filter, view_type.to_sym, k, v, data) }
            .sort_by { |v| v[0] }
            .group_by { |f| f[1] }
            .transform_keys { |k| I18n.t("filter_groups.#{k}", default: k, locale: user.ui_locale) }
        end

        def available_visible_filters(user, view_type, filter_config)
          return [] unless enabled? && !user.nil? && filter_config.is_a?(Array)

          filters = []

          filter_config.each do |filter|
            k, v = filter.first
            filters.concat(try(k.to_sym, user, v) || default(user, k.to_s, v) || [])
          end

          filters.select { |k, v, data| user&.can?(:advanced_filter, view_type.to_sym, k, v, data) }.reverse
        end

        def advanced_attribute_classification_tree_label(specific_type)
          configuration.dig('advanced_attributes', specific_type, 'tree_label')
        end

        def available_advanced_attribute_filters
          return {} unless enabled?
          configuration.dig('advanced_attributes') || {}
        end

        def classification_alias_ids(user, value)
          return [] unless value

          query = DataCycleCore::ClassificationTreeLabel.all
          query = query.where(name: value) if value.is_a?(Array)
          query.map do |c|
            [
              I18n.t("filter.classification_alias_ids.#{c.name.underscore_blanks}", default: I18n.t("filter.#{c.name.underscore_blanks}", default: c.name, locale: user.ui_locale), locale: user.ui_locale),
              'classification_alias_ids',
              data: { name: c.name, visible: c.visibility&.include?('filter') }
            ]
          end
        end

        def relation_filter(user, value)
          return [] unless value.is_a?(Hash)

          value.map { |k, v|
            next unless v

            [
              I18n.t("filter.relation_filter.#{k.underscore_blanks}", default: I18n.t("filter.#{k.underscore_blanks}", default: k.capitalize, locale: user.ui_locale), locale: user.ui_locale),
              'relation_filter',
              data: { name: k, advancedType: v.is_a?(::Hash) ? v['attribute'] : v }
            ]
          }.compact
        end

        def relation_filter_inv(user, value)
          return [] unless value.is_a?(Hash)

          value.map { |k, v|
            next unless v

            [
              I18n.t("filter.relation_filter_inv.#{k.underscore_blanks}", default: I18n.t("filter.#{k.underscore_blanks}", default: k.capitalize, locale: user.ui_locale), locale: user.ui_locale),
              'relation_filter_inv',
              data: { name: k, advancedType: v.is_a?(::Hash) ? v['attribute'] : v }
            ]
          }.compact
        end

        def graph_filter(user, value)
          return [] unless value.is_a?(Hash)

          return [] unless DataCycleCore::ContentContent::Link.any?

          value.slice('items_linked_to', 'linked_items_in').map { |k, v|
            next unless v

            [
              I18n.t("filter.graph_filter.dropdown_text.#{k.underscore_blanks}", default: k.capitalize, locale: user.ui_locale),
              'graph_filter',
              data: { name: k }
            ]
          }.compact
        end

        def union_filter_ids(user, value)
          return [] unless value

          [
            [
              I18n.t('filter.union_filter_ids', collections: DataCycleCore::WatchList.model_name.human(count: 2, locale: user.ui_locale), default: 'union_filter_ids'.capitalize, locale: user.ui_locale),
              'union_filter_ids',
              data: { name: 'union_filter_ids'.capitalize }
            ]
          ]
        end

        def geo_filter(user, value)
          if value.is_a?(Hash)
            value_arr = []
            value.each do |k, v|
              if v.is_a?(Array)
                v.map do |c|
                  value_arr << [
                    I18n.t("filter.geo_filter.#{c.underscore_blanks}", default: I18n.t("filter.#{c.underscore_blanks}", default: c, locale: user.ui_locale), locale: user.ui_locale),
                    'geo_filter',
                    data: { name: c, advancedType: k }
                  ]
                end
              elsif v
                value_arr << [
                  I18n.t("filter.geo_filter.#{k.underscore_blanks}", default: I18n.t("filter.#{k.underscore_blanks}", default: k.capitalize, locale: user.ui_locale), locale: user.ui_locale),
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

        def date_range(user, value)
          if value == 'all'
            ['created_at', 'updated_at'].map do |c|
              [
                I18n.t("filter.date_range.#{c.underscore_blanks}", default: I18n.t("filter.#{c.underscore_blanks}", default: c, locale: user.ui_locale), locale: user.ui_locale),
                'date_range',
                data: { name: c }
              ]
            end
          elsif value.is_a?(Hash)
            value.keys.map do |c|
              [
                I18n.t("filter.date_range.#{c.to_s.underscore_blanks}", default: I18n.t("filter.#{c.to_s.underscore_blanks}", default: c, locale: user.ui_locale), locale: user.ui_locale),
                'date_range',
                data: { name: c }
              ]
            end
          elsif value.is_a?(Array)
            value.map do |c|
              [
                I18n.t("filter.date_range.#{c.underscore_blanks}", default: I18n.t("filter.#{c.underscore_blanks}", default: c, locale: user.ui_locale), locale: user.ui_locale),
                'date_range',
                data: { name: c }
              ]
            end
          else
            []
          end
        end

        def boolean(user, value = [])
          value = ['duplicate_candidates'] if value == 'all'

          value.presence&.map do |c|
            [
              I18n.t("filter.boolean.#{c.underscore_blanks}", default: I18n.t("filter.#{c.underscore_blanks}", default: c, locale: user.ui_locale), locale: user.ui_locale),
              'boolean',
              data: { name: c }
            ]
          end || []
        end

        def related_through_attribute(user, value)
          return [] unless value.is_a?(Hash)

          value.map { |k, v|
            next unless v

            [
              I18n.t("filter.related_through_attribute.#{k.underscore_blanks}", default: k.capitalize, locale: user.ui_locale),
              'related_through_attribute',
              data: { name: k, advancedType: v.is_a?(::Hash) ? v['attribute'] : v }
            ]
          }.compact
        end

        def default(user, key, value)
          return [] unless value
          [
            [
              I18n.t("filter.#{key.underscore_blanks}", default: key.capitalize, locale: user.ui_locale),
              key,
              data: { name: key.capitalize }
            ]
          ]
        end

        def user(user, value)
          return [] unless value

          value.map { |k, v|
            next unless v

            [
              I18n.t("filter.user.#{k.underscore_blanks}", default: I18n.t("filter.#{k.underscore_blanks}", default: k.capitalize, locale: user.ui_locale), locale: user.ui_locale),
              'user',
              data: { name: k, advancedType: k }
            ]
          }.compact
        end

        def advanced_attributes(user, value)
          return [] unless value
          value.map do |k, v|
            [
              I18n.t("filter.advanced_attributes.#{k.underscore_blanks}", default: I18n.t("filter.#{k.underscore_blanks}", default: k, locale: user.ui_locale), locale: user.ui_locale),
              'advanced_attributes',
              data: { name: k, advancedType: v.dig('type') }
            ]
          end
        end

        def inactive_things(user, value)
          return [] unless value
          value.map { |k, v|
            next unless v

            [
              I18n.t("filter.in_schedule_types.#{k.underscore_blanks}", default: k, locale: user.ui_locale),
              'inactive_things',
              data: { name: k, advancedType: k }
            ]
          }.compact
        end

        def in_schedule(user, value)
          return [] unless value
          value.map { |k, v|
            next unless v

            [
              I18n.t("filter.in_schedule_types.#{k.underscore_blanks}", default: k, locale: user.ui_locale),
              'in_schedule',
              data: { name: k, advancedType: k }
            ]
          }.compact
        end

        def validity_period(user, value)
          return [] unless value
          value.map { |k, v|
            next unless v

            [
              I18n.t("filter.in_schedule_types.#{k.underscore_blanks}", default: k, locale: user.ui_locale),
              'validity_period',
              data: { name: k, advancedType: k }
            ]
          }.compact
        end

        def always_visible?
          !!configuration.dig(:config, :visible)
        end

        def schedule_filter_exceptions
          Array.wrap(configuration.dig(:config, :schedule_exceptions))
        end

        def schedule_filter_exceptions_string(locale)
          schedule_filter_exceptions
            &.map { |e| I18n.t("schedule.filter_labels.#{e}", locale:) }
            &.join(', ')
        end

        def relation_filter_restrictions(type, name)
          return unless configuration.dig(type, name).is_a?(::Hash)

          configuration.dig(type, name, 'filter')
        end

        def graph_filter_restrictions(type, name)
          return unless configuration.dig(type, name).is_a?(::Hash)
          configuration.dig(type, name, 'filter')
        end

        def graph_filter_relations(relations: nil)
          query = DataCycleCore::ContentContent::Link
            .includes(:content_a, :content_b)
            .distinct.where.not(relation: nil)
            .where.not(content_a: { content_type: 'embedded' })
            .where.not(content_b: { content_type: 'embedded' })

          query = query.where(relation: relations) if relations.present?

          query
            .pluck('content_content_links.relation, content_a.template_name')
            .group_by(&:first)
            .transform_values { |v| v.map(&:second).uniq }
        end
      end
    end
  end
end
