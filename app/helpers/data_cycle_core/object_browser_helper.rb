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
        filters = filter_definition(definition).filter_map do |conf|
          value = conf[:extractor]
          next if value.blank?

          {
            value: value,
            method_name: conf[:method]
          }
        end

        # raise error to not fail silently

        query_filter = { query_methods: [] }

        filters.each do |filter|
          query_filter[:query_methods] << {
            method_name: filter[:method_name],
            value: filter[:value]
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

    private

    def filter_definition(definition)
      [
        { extractor: extract_aliases(definition, 'Inhaltstypen'), method: 'with_default_data_type' },
        { extractor: extract_aliases(definition, 'SchemaTypes'), method: 'with_schema_type' },
        { extractor: extract_classification_paths(definition, with_not: false).filter { _1.include?('SchemaTypes') }, method: 'with_schema_classification_paths' },
        { extractor: extract_classification_paths(definition, with_not: false).filter { _1.include?('Inhaltstypen') }, method: 'with_content_classification_paths' },

        { extractor: extract_aliases(definition, 'Inhaltstypen', with_not: true), method: 'without_default_data_type' },
        { extractor: extract_aliases(definition, 'SchemaTypes', with_not: true), method: 'without_schema_type' },
        { extractor: extract_classification_paths(definition, with_not: true).filter { _1.include?('SchemaTypes') }, method: 'without_schema_classification_paths' },
        { extractor: extract_classification_paths(definition, with_not: true).filter { _1.include?('Inhaltstypen') }, method: 'without_content_classification_paths' }
      ]
    end
  end
end
