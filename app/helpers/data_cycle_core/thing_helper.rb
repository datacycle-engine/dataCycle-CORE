# frozen_string_literal: true

module DataCycleCore
  module ThingHelper
    def async_thing_select_options(value, template_filter = true)
      return options_for_select([]) if value.blank?

      value = Array.wrap(value)

      options_for_select(
        value.map do |c|
          [
            "#{"<b>#{c.template_name}</b>: " unless template_filter}#{I18n.with_locale(c.first_available_locale) { c.title }} (#{c.translated_locales.join(', ')})",
            c.id,
            {
              title: "#{"#{c.template_name}: " unless template_filter}#{I18n.with_locale(c.first_available_locale) { c.title }} (#{c.translated_locales.join(', ')})",
              class: "#{c.template_name.underscore_blanks} #{c.schema_type&.underscore_blanks}"
            }
          ]
        end,
        value.pluck(:id)
      )
    end

    def content_warning_text(content)
      content.content_warnings.map { |w| DataCycleCore::LocalizationService.translate_and_substitute(w, active_ui_locale) }
    end
  end
end
