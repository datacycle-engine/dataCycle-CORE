# frozen_string_literal: true

module DataCycleCore
  module DataHashHelper
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes + ['id']
    GROUP_FLAGS = [
      'collapsible',
      'one_line',
      'collapsed',
      'two_columns',
      'three_columns',
      'four_columns'
    ].freeze

    def object_from_definition(definition)
      return nil if definition.blank? || definition['template_name'].nil?

      template_name = definition['template_name']
      DataCycleCore::Thing.new(template_name:)
    end

    def attribute_group_title(content, key)
      label_html = ActionView::OutputBuffer.new
      label_html << tag.i(class: "dc-type-icon property-icon key-#{key.attribute_name_from_key} type-object")

      if I18n.exists?("attribute_labels.#{content&.template_name}.#{key.attribute_name_from_key}", count: 1, locale: active_ui_locale)
        label_html << tag.span(I18n.t("attribute_labels.#{content&.template_name}.#{key.attribute_name_from_key}", count: 1, locale: active_ui_locale))
      elsif I18n.exists?("attribute_labels.#{key.attribute_name_from_key}", count: 1, locale: active_ui_locale)
        label_html << tag.span(I18n.t("attribute_labels.#{key.attribute_name_from_key}", count: 1, locale: active_ui_locale))
      else
        return
      end

      label_html << render('data_cycle_core/contents/helper_text', key:, content:)

      label_html
    end

    def ordered_validation_properties(validation:, type: nil, content_area: nil, scope: :edit, exclude_types: [], exclude_keys: [])
      return if validation.nil? || validation['properties'].blank?

      ordered_props = {}

      validation['properties'].sort_by { |_, prop| prop['sorting'] }.each do |key, prop|
        next if Array.wrap(exclude_keys).include?(key)
        next if Array.wrap(exclude_types).include?(prop['type'])
        next if INTERNAL_PROPERTIES.include?(key) || prop['sorting'].blank?
        next if type.present? && prop['type'] != type
        next if content_area.presence&.!=('content') && prop.dig('ui', scope.to_s, 'content_area') != content_area
        next if content_area == 'content' && prop.dig('ui', scope.to_s, 'content_area').present?

        add_attribute_config(key, prop, scope, content_area, ordered_props)
      end

      ordered_props
    end

    def content_header_classification_aliases(content:, scope: :show, context: :show)
      classification_aliases = {}
      parameters = {
        allowed_properties: ordered_header_classification_properties(content:, scope:),
        classification_aliases:,
        options: { ui_scope: :show },
        scope:,
        context:,
        content:
      }

      content.classification_content.preload(classification: [primary_classification_alias: [:classification_tree_label, :classification_alias_path]]).group_by(&:relation).each { |key, ccs| ccs.each { |cc| add_content_header_classification_alias(**parameters, key:, classification_alias: cc.classification&.primary_classification_alias) } }

      content.mapped_classification_aliases.preload(:classification_tree_label, :classification_alias_path).find_each do |ca|
        add_content_header_classification_alias(**parameters, key: '', classification_alias: ca, type: :mapped_value)
      end

      classification_aliases.each_value do |v|
        v[:value].uniq!(&:id)
        v[:mapped_value].uniq!(&:id)

        next unless v[:key] == 'universal_classifications'

        tree_label = v.dig(:definition, 'tree_label')

        next if tree_label.blank?

        k, prop = content.property_definitions.detect { |_k, d| d.key?('content_score') && Array.wrap(d.dig('compute', 'parameters')).include?('universal_classifications') && d.dig('compute', 'tree_label') == tree_label }

        next if k.blank? || prop.blank?

        v[:definition]['content_score'] = prop['content_score'].merge({ 'key' => k })
      end

      classification_aliases.sort_by { |_, v| v.dig(:definition, 'sorting') || 999 }.to_h
    end

    def add_content_header_classification_alias(allowed_properties:, classification_aliases:, key:, classification_alias:, scope:, context:, content:, options: {}, type: :value)
      return if classification_alias.nil?
      return if DataCycleCore::Feature::LifeCycle.enabled? && can?(:show, DataCycleCore::Feature::LifeCycle.data_attribute(content)) && type == :value && key == DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(content)&.first

      ui_config = content&.properties_for(key)&.[]('ui').to_h
      ui_config.merge!(ui_config[scope.to_s].to_h) if ui_config.present?

      if context == :show && ui_config.key?('disabled')
        return if ui_config['disabled'].to_s == 'true'
      else
        return unless classification_alias.classification_tree_label.visibility&.include?(context.to_s)
      end

      definition = allowed_properties[key]&.deep_dup || {}
      definition['tree_label'] ||= classification_alias.classification_tree_label.name
      definition['type'] ||= 'classification'
      label = translated_attribute_label(key, definition, content, options)
      classification_aliases[label] ||= { key:, definition:, options:, value: [], mapped_value: [] }
      classification_aliases[label][type] << classification_alias
    end

    def ordered_header_classification_properties(content:, scope: :show)
      content.property_definitions
        .slice(*content.classification_property_names)
        .select do |k, v|
          next false if INTERNAL_PROPERTIES.include?(k)
          next false unless v.key?('sorting')
          next false if v.dig('ui', scope.to_s, 'disabled').to_s == 'true'
          next false if !v.dig('ui', scope.to_s)&.key?('disabled') && v.dig('ui', 'disabled').to_s == 'true'
          true
        end
    end

    def add_attribute_config(key, prop, scope, content_area, ordered_props)
      return ordered_props[key] = prop.dup unless content_area != 'header' && (prop['ui']&.key?('attribute_group') || prop.dig('ui', scope.to_s)&.key?('attribute_group'))

      cloned_props = prop.deep_dup
      cloned_props['ui'].delete('attribute_group') if cloned_props['ui']&.key?('attribute_group') && cloned_props.dig('ui', scope.to_s)&.key?('attribute_group')

      prop_context = cloned_props.dig('ui', scope.to_s)&.key?('attribute_group') ? cloned_props['ui'][scope.to_s] : cloned_props['ui']
      group = prop_context.then { |g| g['attribute_group'].is_a?(::Array) ? g['attribute_group'].shift : g.delete('attribute_group') }
      prop_context.delete('attribute_group') if prop_context.key?('attribute_group') && prop_context['attribute_group'].blank?
      group_name = group.remove(*GROUP_FLAGS.map { |f| "_#{f}" })

      ordered_props[group_name] ||= {
        'type' => 'attribute_group',
        'properties' => {},
        'features' => GROUP_FLAGS.index_with { |f| group.include?("_#{f}") }.compact_blank
      }

      ordered_props[group_name]['properties'][key] = cloned_props
    end

    def to_html_string(title, text = '')
      html_title = title.presence || ''
      html_title += ': ' if text.present?

      html_text = text.presence || ''

      out = []
      out << tag.span(html_title.html_safe)
      out << tag.b(html_text.html_safe)
      safe_join(out)
    end
  end
end
