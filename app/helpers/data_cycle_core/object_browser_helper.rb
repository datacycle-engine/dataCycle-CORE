# frozen_string_literal: true

module DataCycleCore
  module ObjectBrowserHelper
    def extract_aliases(definition, type, with_not: false)
      definition&.dig('stored_filter')&.flat_map { |filter|
        filter&.values&.filter_map do |val|
          next unless val.is_a?(Hash)
          next unless val.value?(type)
          next unless val.any? { |k, _| k.to_s.downcase.include?('not') } == with_not

          val['aliases']
        end
      }&.compact&.flatten
    end

    def extract_classification_paths(definition, with_not: false)
      definition&.dig('stored_filter')&.flat_map { |entry|
        entry.select { |key, _|
          key.to_s.include?('with_classification_paths') && with_not == key.to_s.include?('not')
        }.values
      }&.compact&.flatten
    end

    def object_browser_new_form_parameters(form_parameters, definition)
      # stored_filter should primarily be used for creating new content
      # if it is not present, we try to find a template by name
      # some definitions might have both, a stored_filter and template_name
      if definition&.dig('stored_filter').present?
        filters = filter_definition(definition)&.select { |f| f[:value].present? }

        if filters.blank?
          ActiveSupport::Notifications.instrument(
            'object_browser.stored_filter.unknown',
            stored_filter: definition['stored_filter']
          )
          return
        end

        query_filter = {
          query_methods: filters.map { |f| { method_name: f[:method], value: f[:value] } }
        }

        creatable_templates = new_content_select_options(**query_filter, scope: 'object_browser')
        return if creatable_templates.blank?
        return form_parameters.merge(template: creatable_templates.first) if creatable_templates.length == 1
        return form_parameters.merge(query_filter)
      end

      if definition&.dig('template_name').present?
        new_template = DataCycleCore::ThingTemplate.find_by(template_name: definition&.dig('template_name'))

        return if new_template.nil? || cannot?(:create, new_template.template_thing, 'object_browser')
        return form_parameters.merge(template: new_template)
      end

      nil
    end

    def limited_by_warning(content, definition, key, translation_key)
      return if definition&.dig('ui', 'edit', 'options', 'limited_by').blank?

      if I18n.exists?("object_browser.limited_by.#{content&.template_name}.#{key.attribute_name_from_key}.#{translation_key}", locale: active_ui_locale)
        I18n.t("object_browser.limited_by.#{content&.template_name}.#{key.attribute_name_from_key}.#{translation_key}", locale: active_ui_locale)
      elsif I18n.exists?("object_browser.limited_by.#{key.attribute_name_from_key}.#{translation_key}", locale: active_ui_locale)
        I18n.t("object_browser.limited_by.#{key.attribute_name_from_key}.#{translation_key}", locale: active_ui_locale)
      elsif I18n.exists?("object_browser.limited_by.#{translation_key}", locale: active_ui_locale)
        I18n.t("object_browser.limited_by.#{translation_key}", locale: active_ui_locale)
      end
    end

    private

    def filter_definition(definition)
      [
        { method: 'with_default_data_type', value: extract_aliases(definition, 'Inhaltstypen')},
        { method: 'with_schema_type', value: extract_aliases(definition, 'SchemaTypes')},
        { method: 'with_schema_classification_paths', value: extract_classification_paths(definition, with_not: false).filter { |item| item.include?('SchemaTypes') } },
        { method: 'with_content_classification_paths', value: extract_classification_paths(definition, with_not: false).filter { |item| item.include?('Inhaltstypen') } },
        { method: 'without_default_data_type', value: extract_aliases(definition, 'Inhaltstypen', with_not: true) },
        { method: 'without_schema_type', value: extract_aliases(definition, 'SchemaTypes', with_not: true) },
        { method: 'without_schema_classification_paths', value: extract_classification_paths(definition, with_not: true).filter { |item| item.include?('SchemaTypes') } },
        { method: 'without_content_classification_paths', value: extract_classification_paths(definition, with_not: true).filter { |item| item.include?('Inhaltstypen') } }
      ]
    end
  end
end
