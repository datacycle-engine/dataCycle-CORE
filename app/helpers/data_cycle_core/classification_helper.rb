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
        .where(classification_tree_labels: { name: treelabel }).any?
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

    def classification_tooltip(concept)
      return if concept.nil?

      tooltip_html = []

      tooltip_html << tag.div(concept.full_path, class: 'tag-full-path') if concept.try(:full_path).present?

      I18n.with_locale(concept.first_available_locale(active_ui_locale)) do
        tooltip_html << "<div class=\"tag-description\">#{concept.description}</div>" if concept.try(:description).present?
      end

      if concept.name_i18n.keys.many?
        tooltip_html << tag.div(
          tag.span(I18n.t('classifications.tooltip_translations', locale: active_ui_locale), class: 'tag-translations-header') +
          tag.ul(
            safe_join(
              concept
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
        .assignable
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
                },
                disabled: !ca.assignable
              }
            ]
          end,
        value.pluck(:id)
      )
    end

    def simple_classification_select_options(value, classification_items, expected_type = DataCycleCore::ClassificationAlias)
      value = Array.wrap(value).compact
      full_classification_items = (classification_items + value).uniq { |v| expected_value_id(v, expected_type) }

      options_for_select(
        full_classification_items
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
                disabled: !ca.assignable
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

    def group_key_for_ctl(ctl, es)
      return es[ctl.external_source_id]&.name || ctl.external_source_id if ctl.external_source_id.present?

      es.values
        .filter { |s|
        ctl.name.to_s.downcase.start_with?(s.name.to_s.downcase) ||
          ctl.name.to_s.downcase.start_with?(s.identifier.to_s.downcase)
      }
        .min_by { |s|
        [
          DidYouMean::Levenshtein.distance(ctl.name.to_s.downcase, s.name.to_s.downcase),
          DidYouMean::Levenshtein.distance(ctl.name.to_s.downcase, s.identifier.to_s.downcase)
        ].min
      }&.name || (ctl.name.split(' - ').many? ? ctl.name.split(' - ').first : nil)
    end

    def grouped_classification_tree_labels(classification_tree_labels)
      es = DataCycleCore::ExternalSystem.all.index_by(&:id)

      classification_tree_labels
        .group_by { |tree_label| group_key_for_ctl(tree_label, es) }
        .sort_by { |group_key, _| group_key.to_s.downcase }
        .to_h
        .transform_values { |tree_labels| tree_labels.sort_by { |ctl| ctl.name.to_s.downcase } }
    end

    def concept_scheme_ccc_count(concept_scheme, collection, link_type)
      DataCycleCore::CollectedClassificationContent.where(
        link_type:,
        classification_tree_label_id: concept_scheme.id,
        thing_id: collection.things.reorder(nil).select(:id)
      ).distinct.count(:thing_id)
    end

    def matched_concept_path(name, matches)
      return name if matches.blank?
      matched_name = ''
      rest = name

      matches.each do |m|
        index = rest =~ /#{m}/i
        next if index.nil?
        index_end = index + m.size
        matched_name += rest[0...index]
        matched_name += "<mark>#{rest[index...index_end]}</mark>"
        rest = rest[index_end..-1]
      end

      matched_name + rest
    end
  end
end
