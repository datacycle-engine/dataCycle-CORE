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

    def content_warning_class(content)
      if content.hard_content_warnings?
        'content-alert alert'
      elsif content.soft_content_warnings?
        'content-warning warning'
      end
    end

    def content_warning_text(content)
      safe_join(content.content_warnings.map { |w| DataCycleCore::LocalizationService.translate_and_substitute(w, active_ui_locale) }, tag.br)
    end

    def content_tile_class(content, type = 'grid')
      css_classes = ["#{type}-item", 'data-cycle-object']

      return css_classes.join(' ') if content.nil?

      css_classes << content.template_name.underscore_blanks if content.respond_to?(:template_name)
      css_classes << Feature::TileBorderColor.class_string(content)
      css_classes << thing_content_score_class(content)

      css_classes.compact_blank.join(' ')
    end
  end
end
