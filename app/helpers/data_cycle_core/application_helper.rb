module DataCycleCore
  module ApplicationHelper
    DEFAULT_KEY_MATCHING = {
      alert: :alert,
      notice: :success,
      info: :info,
      secondary: :secondary,
      success: :success,
      error: :alert,
      warning: :warning,
      primary: :primary
    }

    def available_locales_with_names
      Hash[I18n.available_locales.collect { |l| [l, I18n.t('locales.' + l.to_s, locale: DataCycleCore.ui_language).try(:capitalize)] }]
    end

    def display_flash_messages_new(closable: true)
      capture do
        flash.each do |key, value|
          alert_class = DEFAULT_KEY_MATCHING[key.to_sym]
          concat alert_box(value, alert_class, closable)
        end
      end
    end

    def display_flash_messages_resource(closable: true)
      capture do
        resource.errors.messages.each do |value|
          text_string = "#{value[0]} #{value[1][0]}"
          concat alert_box(text_string, :alert, closable)
        end
      end
    end

    # Returns the full title on a per-page basis.
    def full_title
      base_title = 'DataCycle'

      if content_for(:title).nil? || content_for(:title).empty?
        base_title
      else
        content_for(:title) + ' | ' + base_title
      end
    end

    def render_content_partial(partial, parameters)
      partials = [
        "#{parameters[:content].class.class_name.underscore}_#{parameters[:content].content_type.underscore}_#{partial}",
        "#{parameters[:content].class.class_name.underscore}_#{partial}",
        "content_#{partial}"
      ]

      render_first_existing_partial(partials, parameters)
    end

    def render_attribute_editor(key:, definition:, value:, parameters: {})
      partials = [
        (definition.try(:[], 'releasable') ? 'releasable' : '').to_s,
        definition.try(:[], 'editor').try(:[], 'options').try(:[], 'type').try(:underscore).to_s,
        definition.try(:[], 'editor').try(:[], 'type').try(:underscore).to_s,
        definition['type'].underscore.to_s
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/#{p}_editor" }
      parameters[:options]['readonly'] = !can?(:edit, DataCycleCore::DataAttribute.new(key, definition, parameters[:options]))
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value }))
    end

    def render_attribute_viewer(key:, definition:, value:, parameters: {})
      partials = [
        parameters.dig(:options).dig(:force_partial).try(:underscore).to_s,
        "#{definition['type'].underscore}_#{definition.try(:[], 'editor').try(:[], 'options').try(:[], 'data-type').try(:underscore)}",
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        definition.try(:[], 'editor').try(:[], 'type').try(:underscore).to_s,
        definition['type'].underscore.to_s
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/#{p}_viewer" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value }))
    end

    def render_content_tile(item:, parameters: {})
      partials = [
        "#{item.try(:metadata).try(:dig, 'validation', 'name')}_#{item.try(:metadata).try(:dig, 'validation', 'description')}".underscore.parameterize(separator: '_'),
        item.try(:metadata).try(:dig, 'validation', 'description').to_s.underscore.parameterize(separator: '_'),
        item.try(:class).try(:name).try(:demodulize).to_s.underscore.parameterize(separator: '_'),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/tiles/#{p}_tile" }

      render_first_existing_partial(partials, parameters.merge({ item: item }))
    end

    def render_attribute_history_viewer(key:, definition:, value:, parameters: {})
      partials = [
        "#{definition['type'].underscore}_#{definition.try(:[], 'editor').try(:[], 'options').try(:[], 'data-type').try(:underscore)}",
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        definition.try(:[], 'editor').try(:[], 'type').try(:underscore).to_s,
        definition['type'].underscore.to_s
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/history_viewers/#{p}_history_viewer" }

      begin
        render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value }))
      rescue StandardError
        render_attribute_viewer key: key, definition: definition, value: value, parameters: parameters
      end
    end

    def render_object_browser_partial(partial: 'tile', key:, definition:, parameters: {})
      partials = [
        definition.dig('editor', 'options', 'data-type').try(:underscore).to_s,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/object_browser/#{p}_#{partial}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition }))
    end

    def render_embedded_object_partial(partial: 'detail', key:, definition:, parameters: {})
      partials = [
        "#{definition.try(:[], 'name')}_#{definition.try(:[], 'description')}".underscore.parameterize(separator: '_'),
        definition.try(:[], 'description').to_s.underscore.parameterize(separator: '_'),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/embedded_object/#{p}_#{partial}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition }))
    end

    def render_asset_partial(partial: 'detail', key:, value:, definition:, parameters: {})
      partials = [
        definition.try(:[], 'editor').try(:[], 'type').to_s.try(:underscore),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/asset/#{p}_#{partial}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value }))
    end

    private

    def render_first_existing_partial(partials, parameters)
      partials.each_with_index do |partial, idx|
        begin
          logger.debug "  Try rendering partial #{partial} ..."
          return render(partial, parameters)
        rescue ActionView::MissingTemplate => e
          logger.debug "  Try rendering partial #{partial} ... [NOT FOUND]"
          raise e if idx == partials.size - 1
        end
      end
    end

    def alert_box(value, alert_class, closable)
      options = { class: "flash callout #{alert_class}" }
      options[:data] = { closable: '' } if closable
      content_tag(:div, options) do
        concat value.to_s
        concat close_link if closable
      end
    end

    def close_link
      button_tag(
        class: 'close-button',
        type: 'button',
        data: { close: '' },
        aria: { label: 'Dismiss alert' }
      ) do
        content_tag(:span, '&times;'.html_safe, aria: { hidden: true })
      end
    end
  end
end
