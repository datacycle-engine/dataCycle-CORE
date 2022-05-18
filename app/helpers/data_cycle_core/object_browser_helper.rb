# frozen_string_literal: true

module DataCycleCore
  module ObjectBrowserHelper
    def object_browser_new_form_parameters(form_parameters, definition)
      if definition&.dig('stored_filter').present?
        creatable_ids = definition&.dig('stored_filter')&.map { |v| v&.values&.select { |c| c.is_a?(Hash) && c&.value?('Inhaltstypen') }&.map { |c| c&.dig('aliases') } }&.flatten&.compact

<<<<<<< HEAD
        return nil if creatable_ids.blank?
=======
        return if creatable_ids.blank?
>>>>>>> old/develop

        query_filter = {
          query_methods: [{
            method_name: 'with_default_data_type',
            value: creatable_ids
          }]
        }

        creatable_templates = new_content_select_options(query_filter.merge({ scope: 'object_browser' }))

<<<<<<< HEAD
        return nil if creatable_templates.blank?
=======
        return if creatable_templates.blank?
>>>>>>> old/develop

        return form_parameters.merge(template: creatable_templates.first) if creatable_templates.length == 1

        return form_parameters.merge(query_filter)
      elsif definition&.dig('template_name').present?
        new_template = DataCycleCore::Thing.find_by(template: true, template_name: definition&.dig('template_name'))

<<<<<<< HEAD
        return nil if new_template.nil? || cannot?(:create, new_template, 'object_browser')
=======
        return if new_template.nil? || cannot?(:create, new_template, 'object_browser')
>>>>>>> old/develop

        return form_parameters.merge(template: new_template)
      end

      nil
    end
<<<<<<< HEAD
=======

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
>>>>>>> old/develop
  end
end
