# frozen_string_literal: true

module DataCycleCore
  module ClassificationHelper
    # TODO: refactor
    def get_classifications_for_name(name)
      return if name.blank?

      DataCycleCore::ClassificationTreeLabel
        .includes(classification_trees: [:classification_tree_label, :sub_classification_alias])
        .find_by(name:)
    end

    # TODO: refactor
    def get_classifications_for_id(uids, tree_label = nil)
      unless uids.nil?
        if tree_label.nil?
          @selected_classifications = DataCycleCore::ClassificationAlias.find(uids)
        else
          allowed_classifications = get_classifications_for_name(tree_label)
            .classification_trees
            .map { |classification| classification.sub_classification_alias.id }
          allowed_uids = uids.select { |uid| allowed_classifications.include?(uid) }
          @selected_classifications = DataCycleCore::ClassificationAlias.find(allowed_uids)
        end
      end
    rescue StandardError
      logger.warn("cannot find classifications for the following ids: #{(uids || []).join(', ')}")
      nil
    end

    def classification_tree_label_has_children?(treelabel)
      DataCycleCore::Classification
        .includes(:classification_groups, :classification_aliases)
        .joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where(classification_tree_labels: { name: treelabel }).count.positive?
    end

    def classification_title(classification_or_alias)
      if classification_or_alias.is_a?(DataCycleCore::Classification)
        classification_or_alias.try(:name) || classification_or_alias.try(:external_key) || 'NO_NAME'
      elsif classification_or_alias.is_a?(DataCycleCore::ClassificationAlias)
        classification_or_alias.try(:internal_name) || classification_or_alias.try(:primary_classification).try(:external_key) || 'NO_NAME'
      else
        'DELETED'
      end
    end

    def classification_path_classes(classification_alias)
      return if classification_alias&.classification_alias_path&.full_path_names.nil?

      tree_label = classification_alias.classification_alias_path.full_path_names.last
      classification_alias
        .classification_alias_path
        .full_path_names
        .except(tree_label)
        .map { |c_name| "#{tree_label}_#{c_name}".underscore_blanks }
        .join(' ')
    end

    def classification_style(classification_alias)
      return unless classification_alias&.color?

      "--classification-color: #{classification_alias.color};"
    end

    def classification_tooltip(classification_alias)
      return if classification_alias.nil?

      tooltip_html = []

      tooltip_html << tag.div(classification_alias.full_path, class: 'tag-full-path') if classification_alias.try(:full_path).present?

      I18n.with_locale(classification_alias.first_available_locale(active_ui_locale)) do
        tooltip_html << "<div class=\"tag-description\">#{classification_alias.description}</div>" if classification_alias.try(:description).present?
      end

      if classification_alias.name_i18n.keys.many?
        tooltip_html << tag.div(
          tag.span(I18n.t('classifications.tooltip_translations', locale: active_ui_locale), class: 'tag-translations-header') +
          tag.ul(
            safe_join(
              classification_alias
                .name_i18n
                .each_with_object({}) { |(k, v), h|
                (h[v] ||= []) << k
              }
                .transform_values { |v| v.sort.join(', ') }
                .sort_by { |_k, v| v }
                .map { |k, v| tag.li(ActionView::OutputBuffer.new("#{k} #{tag.span("(#{v})", class: 'tag-translations-locales')}")) }
            ),
            class: 'tag-translations-list'
          ),
          class: 'tag-translations'
        )
      end

      tooltip_html.compact.join('<br>')
    end

    def expected_classification_alias(c)
      c.is_a?(DataCycleCore::Classification) ? c&.primary_classification_alias : c
    end

    def expected_value_id(c, expected_type)
      if c.is_a?(expected_type)
        c&.id
      elsif expected_type == DataCycleCore::Classification
        c&.primary_classification&.id
      else
        c&.primary_classification_alias&.id
      end
    end

    def classification_alias_filter_items(tree_label, order_by = nil)
      return DataCycleCore::ClassificationAlias.none if tree_label.blank?

      DataCycleCore::ClassificationAlias
        .for_tree(tree_label)
        .includes(
          :primary_classification, :classification_alias_path, sub_classification_alias: [
            :primary_classification, :classification_alias_path, {sub_classification_alias: [
              :primary_classification, :classification_alias_path, :sub_classification_alias
            ]}
          ]
        )
        .order(order_by)
    end

    def async_classification_select_options(value, expected_type = DataCycleCore::ClassificationAlias)
      value = Array.wrap(value).compact

      return options_for_select([]) if value.blank?

      options_for_select(
        value
          .filter_map do |c|
            ca = expected_classification_alias(c)
            next if ca.nil?

            [
              ca.internal_name,
              expected_value_id(c, expected_type),
              {
                data: {
                  dc_tooltip: classification_tooltip(ca),
                  full_path: ca.full_path
                }
              }
            ]
          end,
        value.pluck(:id)
      )
    end

    def simple_classification_select_options(value, classification_items, expected_type = DataCycleCore::ClassificationAlias, disabled_proc = nil)
      value = Array.wrap(value).compact
      options_for_select(
        classification_items
          &.filter_map do |c|
            ca = expected_classification_alias(c)
            next if ca.nil?

            next if ca.classification_alias_path&.full_path_names&.last == 'Inhaltstypen' && DataCycleCore.excluded_filter_classifications.include?(ca.internal_name)

            [
              ca.internal_name,
              expected_value_id(c, expected_type),
              {
                data: {
                  dc_tooltip: classification_tooltip(ca),
                  full_path: ca.full_path
                },
                disabled: disabled_proc.present? ? disabled_proc.call(ca) : !ca.assignable
              }
            ]
          end,
        value&.pluck(:id)
      )
    end

    def classification_select_config(key, definition, options, content, additional_options = {})
      single_select = definition.dig('ui', 'edit', 'options', 'multiple') == false || definition.dig('validations', 'max') == 1

      {
        multiple: !single_select,
        include_blank: single_select,
        disabled: !attribute_editable?(key, definition, options, content),
        class: 'multi-select',
        data: {
          allow_clear: definition.dig('validations', 'required') != true,
          tree_label: definition['tree_label'],
          max: 20,
          close_on_select: single_select,
          placeholder: '',
          find_path: find_classifications_path,
          search_path: search_classifications_path
        },
        id: "#{options&.dig(:prefix)}#{sanitize_to_id(key)}"
      }.with_indifferent_access
        .merge(additional_options)
        .merge(definition.dig('ui', 'edit', 'options')&.except('class') || {})
        .tap { |h| h['class'] = "#{h['class']} #{definition.dig('ui', 'edit', 'options', 'class')}".squish }
    end
  end
end
