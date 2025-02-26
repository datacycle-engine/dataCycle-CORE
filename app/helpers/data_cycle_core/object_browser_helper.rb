# frozen_string_literal: true

module DataCycleCore
  module ObjectBrowserHelper
    def extract_aliases(definition, type)
      definition&.dig('stored_filter')&.flat_map { |v|
        v&.values&.select { |c| c.is_a?(Hash) && c&.value?(type) }&.map { |c| c&.dig('aliases') }
      }&.compact&.flatten
    end

    def object_browser_new_form_parameters(form_parameters, definition)
      if definition&.dig('stored_filter').present?
        creatable_ids = extract_aliases(definition, 'Inhaltstypen')
        creatable_schema_type_ids = extract_aliases(definition, 'SchemaTypes')

        return if creatable_ids.blank? && creatable_schema_type_ids.blank?

        if creatable_ids.present?
          query_filter = {
            query_methods: [{
              method_name: 'with_default_data_type',
              value: creatable_ids
            }]
          }
        elsif creatable_schema_type_ids.present?
          query_filter = {
            query_methods: [{
              method_name: 'with_schema_type',
              value: creatable_schema_type_ids
            }]
          }
        end

        creatable_templates = new_content_select_options(**query_filter, scope: 'object_browser')

        return if creatable_templates.blank?

        return form_parameters.merge(template: creatable_templates.first) if creatable_templates.length == 1

        return form_parameters.merge(query_filter)
      elsif definition&.dig('template_name').present?
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
  end
end
