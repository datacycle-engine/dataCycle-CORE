# frozen_string_literal: true

module DataCycleCore
  module ObjectBrowserHelper
    FILTER_ORDER = [
      :default_data_type,
      :schema_type,
      :schema_classification_paths,
      :content_classification_paths
    ].freeze

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
      if definition&.dig('template_name').present?
        new_template = DataCycleCore::ThingTemplate.find_by(template_name: definition&.dig('template_name'))

        return if new_template.nil? || cannot?(:create, new_template.template_thing, 'object_browser')
        return form_parameters.merge(template: new_template)
      end

      if definition&.dig('stored_filter').present?
        filters = ordered_filter(definition)&.select { |f| f[:value].present? }

        if filters.blank?
          ActiveSupport::Notifications.instrument(
            'object_browser.stored_filter.unknown',
            stored_filter: definition['stored_filter']
          )

          return
        end

        # If every filter shoud be used
        # query_filter = {
        #   query_methods: filters.map { |f| { method_name: f[:method], value: f[:value] } }
        # }

        query_filter = { query_methods: [] }
        selected_with = filters.find { |f| f[:type] == :with }
        if selected_with
          query_filter[:query_methods] << selected_with

          matching_without = filters.find do |f|
            f[:type] == :without && f[:base] == selected_with[:base]
          end

          query_filter[:query_methods] << matching_without if matching_without
        else
          first_without = filters.find { |f| f[:type] == :without }
          query_filter[:query_methods] << first_without if first_without
        end

        creatable_templates = new_content_select_options(**query_filter, scope: 'object_browser')
        return if creatable_templates.blank?
        return form_parameters.merge(template: creatable_templates.first) if creatable_templates.length == 1
        return form_parameters.merge(query_filter)
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

    def ordered_filter(definition)
      FILTER_ORDER.flat_map do |base|
        [
          {
            type: :with,
            base: base,
            method_name: "with_#{base}",
            value: extract_filter_value(definition, base, with_not: false)
          },
          {
            type: :without,
            base: base,
            method_name: "without_#{base}",
            value: extract_filter_value(definition, base, with_not: true)
          }
        ]
      end
    end

    def extract_filter_value(definition, base, with_not:)
      case base
      when :default_data_type
        extract_aliases(definition, 'Inhaltstypen', with_not: with_not)
      when :schema_type
        extract_aliases(definition, 'SchemaTypes', with_not: with_not)
      when :schema_classification_paths
        extract_classification_paths(definition, with_not: with_not).filter { _1.include?('SchemaTypes') }
      when :content_classification_paths
        extract_classification_paths(definition, with_not: with_not).filter { _1.include?('Inhaltstypen') }
      end
    end

    # def filter_definition(definition)
    #   {
    #     { type: :with, extractor: extract_aliases(definition, 'Inhaltstypen'), method: 'with_default_data_type' },
    #     { type: :with, extractor: extract_aliases(definition, 'SchemaTypes'), method: 'with_schema_type' },
    #     { type: :with, extractor: extract_classification_paths(definition, with_not: false).filter { _1.include?('SchemaTypes') }, method: 'with_schema_classification_paths' },
    #     { type: :with, extractor: extract_classification_paths(definition, with_not: false).filter { _1.include?('Inhaltstypen') }, method: 'with_content_classification_paths' },
    #     { type: :without, extractor: extract_aliases(definition, 'Inhaltstypen', with_not: true), method: 'without_default_data_type' },
    #     { type: :without, extractor: extract_aliases(definition, 'SchemaTypes', with_not: true), method: 'without_schema_type' },
    #     { type: :without, extractor: extract_classification_paths(definition, with_not: true).filter { _1.include?('SchemaTypes') }, method: 'without_schema_classification_paths' },
    #     { type: :without, extractor: extract_classification_paths(definition, with_not: true).filter { _1.include?('Inhaltstypen') }, method: 'without_content_classification_paths' }
    #   }
    # end
  end
end
