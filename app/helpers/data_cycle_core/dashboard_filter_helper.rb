# frozen_string_literal: true

module DataCycleCore
  module DashboardFilterHelper
    RELATION_FILTER_ALLOWED_TYPES = {
      'items_linked_to' => ['i', 'p', 's'],
      'linked_items_in' => ['i', 'e', 'p', 'b', 's', 'u']
    }.freeze

    RELATION_FILTER_TYPES = {
      'i' => 'contained_in',
      'e' => 'not_contained_in',
      'p' => 'exists',
      'b' => 'not_exists',
      's' => 'equal',
      'u' => 'not_equal'
    }.freeze

    def union_ids_to_value(value)
      return [] if value.blank?

      DataCycleCore::Collection.where(id: value).map { |t| t.to_select_option(active_ui_locale) }
    end

    def thing_ids_to_value(value)
      DataCycleCore::Thing.where(id: value)
        .where.not(content_type: 'embedded')
        .includes(:translations)
        .map { |t| t.to_select_option(active_ui_locale) }
    end

    def union_values_to_options(value)
      return if value.blank?

      options_for_select(union_ids_to_value(value).map(&:to_option_for_select), value)
    end

    def thing_values_to_options(value)
      return if value.blank?

      options_for_select(thing_ids_to_value(value).map(&:to_option_for_select), value)
    end

    def relation_filter_items(value, filter_method)
      if filter_method.in?(['i', 'e'])
        union_ids_to_value(value)
      elsif filter_method.in?(['s', 'u'])
        thing_ids_to_value(value)
      end
    end

    def advanced_attribute_filter_options(filter_advanced_type)
      case filter_advanced_type
      when 'string'
        [
          [t('common.is', locale: active_ui_locale), 'i'],
          [t('common.is_not', locale: active_ui_locale), 'e'],
          [t('common.like', locale: active_ui_locale), 's'],
          [t('common.not_like', locale: active_ui_locale), 'u'],
          [t('common.blank', locale: active_ui_locale), 'b'],
          [t('common.present', locale: active_ui_locale), 'p']
        ]
      when 'classification_alias_ids'
        [
          [t('common.has', locale: active_ui_locale), 'i'],
          [t('common.has_not', locale: active_ui_locale), 'e'],
          [t('common.blank', locale: active_ui_locale), 'b'],
          [t('common.present', locale: active_ui_locale), 'p']
        ]
      when 'boolean'
        nil
      else
        [
          [t('common.is', locale: active_ui_locale), 'i'],
          [t('common.is_not', locale: active_ui_locale), 'e']
        ]
      end
    end

    def conditional_filter_accordion(filter_config, &)
      return if filter_config[:filter].blank?

      if filter_config[:collapse]
        tag.div(class: 'accordion filter-collapse', data: { accordion: true, allow_all_closed: true }) do
          tag.div(class: "row accordion-item #{'is-active' if filter_config[:collapse] == 'open'}", data: { accordion_item: true }) do
            tag.section(capture(&), class: 'filters accordion-content', data: { tab_content: true }) +
              tag.a(tag.span(tag.i(class: 'fa fa-chevron-down')), class: 'accordion-title')
          end
        end
      else
        tag.section(capture(&), class: 'filters')
      end
    end

    def in_schedule_filter_options
      DataCycleCore::ApiService::API_SCHEDULE_ATTRIBUTES.except(:schedule)
        .map { |a|
          value = a.to_s.underscore.delete_prefix('dc:')

          [
            I18n.t("schedule.filter_labels.#{value}", default: value, locale: active_ui_locale),
            value
          ]
        }
        .prepend(
          [
            I18n.t(
              'schedule.filter_labels.all',
              exceptions: DataCycleCore::Feature::AdvancedFilter.schedule_filter_exceptions_string(active_ui_locale),
              locale: active_ui_locale
            ),
            nil
          ]
        )
    end

    def in_schedule_filter_title(filter_type, filter_name, filter_title, identifier)
      if filter_type.to_s == 'in_schedule'
        select_tag "f[#{identifier}][n]", options_for_select(in_schedule_filter_options, filter_name)
      else
        tag.span(I18n.t("filter.#{filter_type}", default: filter_title, locale: active_ui_locale))
      end
    end

    def in_schedule_tag_title(filter_type, filter_title, key)
      if filter_type.to_s == 'in_schedule'
        return I18n.t("schedule.filter_labels.#{key}", default: key, locale: active_ui_locale) if key.present?

        I18n.t(
          'schedule.filter_labels.all',
          exceptions: DataCycleCore::Feature::AdvancedFilter.schedule_filter_exceptions_string(active_ui_locale),
          locale: active_ui_locale
        )
      else
        I18n.t("filter.#{filter_type}", default: filter_title, locale: active_ui_locale)
      end
    end

    def advanced_relation_filter_options(filter_method, thing_filter = false)
      filter_options = [
        [t('filter.relation_filter.contained_in', locale: active_ui_locale), 'i'],
        [t('filter.relation_filter.not_contained_in', locale: active_ui_locale), 'e'],
        [t('filter.relation_filter.exists', locale: active_ui_locale), 'p'],
        [t('filter.relation_filter.not_exists', locale: active_ui_locale), 'b']
      ]

      if thing_filter
        filter_options.prepend(
          [t('filter.relation_filter.equal', locale: active_ui_locale), 's'],
          [t('filter.relation_filter.not_equal', locale: active_ui_locale), 'u']
        )
      end

      options_for_select(filter_options, filter_method)
    end

    def advanced_graph_filter_options(filter_method, filter_type)
      filter_options = RELATION_FILTER_TYPES.slice(*RELATION_FILTER_ALLOWED_TYPES[filter_type]).map do |k, v|
        [I18n.t("filter.graph_filter.#{filter_type}.#{v}", locale: active_ui_locale), k]
      end

      options_for_select(filter_options, filter_method)
    end

    def advanced_graph_filter_advanced_type(identifier:, filter_name:, filter_advanced_type:)
      allowed_relations = DataCycleCore::Feature::AdvancedFilter.graph_filter_relations
      thing_template_labels = DataCycleCore::ThingTemplate.translated_property_labels(
        attributes: allowed_relations,
        locale: active_ui_locale,
        count: filter_name == 'linked_items_in' ? 1 : 2,
        specific: filter_name
      ).invert.sort.to_a.map { |(v, k)| [v, k, { data: { dc_tooltip: v } }] }
      # specific keys: items_linked_to, linked_items_in

      select_tag(
        "f[#{identifier}][q]",
        options_for_select(thing_template_labels, filter_advanced_type),
        {
          multiple: false,
          class: 'single-select',
          data: {
            max: 20,
            allow_clear: false
          }
        }
      )
    end

    def selected_filter_params(filter, config)
      if config[:hidden_filter]&.any?(filter)
        { buttons: 'h', container_classes: 'hidden-filter' }
      elsif filter['c'].in?(['a', 'u'])
        { buttons: 'a', container_classes: 'advanced-tags' }
      elsif filter['c'] == 'uf'
        { buttons: false, container_classes: 'user-force-filter' }
      else
        { buttons: 'd' }
      end
    end
  end
end
