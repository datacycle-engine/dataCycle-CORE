# frozen_string_literal: true

module DataCycleCore
  module ObjectBrowserHelper
    def object_browser_new_form_parameters(form_parameters, definition)
      if definition&.dig('stored_filter').present?
        creatable_ids = definition&.dig('stored_filter')&.map { |v| v&.values&.select { |c| c.is_a?(Hash) && c&.value?('Inhaltstypen') }&.map { |c| c&.dig('aliases') } }&.flatten&.compact

        return nil if creatable_ids.blank?

        query_filter = {
          query_methods: [{
            method_name: 'with_default_data_type',
            value: creatable_ids
          }]
        }

        creatable_templates = new_content_select_options(query_filter.merge({ scope: 'object_browser' }))

        return nil if creatable_templates.blank?

        return form_parameters.merge(template: creatable_templates.first) if creatable_templates.length == 1

        return form_parameters.merge(query_filter)
      elsif definition&.dig('template_name').present?
        new_template = DataCycleCore::Thing.find_by(template: true, template_name: definition&.dig('template_name'))

        return nil if new_template.nil? || cannot?(:create, new_template, 'object_browser')

        return form_parameters.merge(template: new_template)
      end

      nil
    end
  end
end
