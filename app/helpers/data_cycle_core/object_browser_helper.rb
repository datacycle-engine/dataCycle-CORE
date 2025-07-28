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
      if definition&.dig('stored_filter').present?
        creatable_ids = extract_aliases(definition, 'Inhaltstypen')
        creatable_schema_type_ids = extract_aliases(definition, 'SchemaTypes')

        creatable_paths = extract_classification_paths(definition, with_not: false)
        creatable_schema_paths = creatable_paths.filter { |path| path.include?('SchemaTypes') }
        creatable_content_paths = creatable_paths.filter { |path| path.include?('Inhaltstypen') }

        exclude_creatable_ids = extract_aliases(definition, 'Inhaltstypen', with_not: true)
        exclude_creatable_schema_type_ids = extract_aliases(definition, 'SchemaTypes', with_not: true)
        exclude_creatable_schema_paths = extract_classification_paths(definition, with_not: true).filter { |path| path.include?('SchemaTypes') }
        exclude_creatable_content_paths = extract_classification_paths(definition, with_not: true)

        return if creatable_ids.blank? && creatable_schema_type_ids.blank? && creatable_paths.blank? && exclude_creatable_ids.blank? &&
                  exclude_creatable_schema_type_ids.blank? && exclude_creatable_schema_paths.blank? && exclude_creatable_content_paths.blank? # raise error to not fail silently

        query_filter = {query_methods: []}
        if creatable_ids.present?
          query_filter[:query_methods] <<
            {
              method_name: 'with_default_data_type',
              value: creatable_ids
            }
        elsif creatable_schema_type_ids.present?
          query_filter[:query_methods] <<
            {
              method_name: 'with_schema_type',
              value: creatable_schema_type_ids
            }
        elsif creatable_schema_paths.present?
          query_filter[:query_methods] <<
            {
              method_name: 'with_schema_classification_paths',
              value: creatable_schema_paths
            }
        elsif creatable_content_paths.present?
          query_filter[:query_methods] <<
            {
              method_name: 'with_content_classification_paths',
              value: creatable_content_paths
            }
        end

        if exclude_creatable_ids.present?
          query_filter[:query_methods] <<
            {
              method_name: 'without_default_data_type',
              value: exclude_creatable_ids
            }

        elsif exclude_creatable_schema_type_ids.present?
          query_filter[:query_methods] <<
            {
              method_name: 'without_schema_type',
              value: exclude_creatable_schema_type_ids
            }
        elsif exclude_creatable_schema_paths.present?
          query_filter[:query_methods] <<
            {
              method_name: 'without_schema_classification_paths',
              value: exclude_creatable_schema_paths
            }
        elsif exclude_creatable_content_paths.present?
          query_filter[:query_methods] <<
            {
              method_name: 'without_content_classification_paths',
              value: exclude_creatable_content_paths
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
      # raise error to not fail silently
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
