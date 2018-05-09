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

      if content_for(:title).blank?
        base_title
      else
        content_for(:title) + ' | ' + base_title
      end
    end

    def attribute_name_from_key(key)
      key.scan(/\[(.*?)\]/).flatten.last
    end

    def add_attribute_options(options, definition, scope)
      attribute_options = definition.try(:[], 'ui').try(:[], scope.to_s).try(:[], 'options')
      attribute_options.nil? ? options : options.merge(attribute_options)
    end

    def render_content_partial(partial, parameters)
      partials = [
        "#{parameters[:content].class.class_name.underscore}_#{parameters[:content].template_name.underscore}_#{partial}",
        "#{parameters[:content].class.class_name.underscore}_#{partial}",
        "content_#{partial}"
      ]

      render_first_existing_partial(partials, parameters)
    end

    def render_attribute_editor(key:, definition:, value:, parameters: {}, content: nil)
      return unless can?(:show, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content, :edit))
      partials = [
        attribute_name_from_key(key).underscore.to_s,
        definition.try(:[], 'ui').try(:[], 'edit').try(:[], 'type').try(:underscore).to_s,
        definition['type'].underscore.to_s
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/#{p}" }

      # TODO: check if required ? refactor readonly
      parameters[:options]['readonly'] = !can?(:edit, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content, :edit))

      parameters[:options] = add_attribute_options(parameters[:options], definition, :edit)
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    # TODO: check force_partial option
    def render_attribute_viewer(key:, definition:, value:, parameters: {}, content: nil)
      return unless can?(:show, DataCycleCore::DataAttribute.new(key, definition, parameters[:options], content), :show)
      partials = [
        key.underscore.to_s,
        definition.try(:[], 'ui').try(:[], 'show').try(:[], 'type').try(:underscore).to_s,
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        definition['type'].underscore.to_s
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/#{p}" }

      parameters[:options] = add_attribute_options(parameters[:options], definition, :show)
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_attribute_history_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.underscore.to_s,
        definition.try(:[], 'ui').try(:[], 'history').try(:[], 'type').try(:underscore).to_s,
        "#{definition['type'].underscore}_#{definition.try(:[], 'validations').try(:[], 'format').try(:underscore)}",
        definition['type'].underscore.to_s
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/history_viewers/#{p}_history_viewer" }
      begin
        render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
      rescue StandardError
        render_attribute_viewer key: key, definition: definition, value: value, parameters: parameters, content: content
      end
    end

    def render_linked_viewer(key:, definition:, value:, parameters: {}, content: nil)
      partials = [
        key.underscore.to_s,
        definition.try(:[], 'ui').try(:[], 'show').try(:[], 'type').try(:underscore).to_s,
        "#{definition.try(:[], 'linked_table').try(:singularize).try(:underscore)}_#{definition.try(:[], 'template_name').try(:parameterize).try(:underscore)}",
        definition.try(:[], 'linked_table').try(:singularize).try(:underscore).to_s,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/linked/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_asset_editor(key:, value:, definition:, parameters: {}, content: nil)
      partials = [
        definition.try(:[], 'asset_type').to_s.try(:underscore),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_asset_viewer(key:, value:, definition:, parameters: {}, content: nil)
      partials = [
        definition.try(:[], 'asset_type').to_s.try(:underscore),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/viewers/asset/#{p}" }
      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, value: value, content: content }))
    end

    def render_content_tile(item:, parameters: {})
      # TODO: [patrick]: add dashboard ability
      partials = [
        "#{item.try(:class).try(:name).try(:demodulize).to_s.underscore.parameterize(separator: '_')}_#{item.try(:template_name)&.underscore&.parameterize(separator: '_')}",
        item.try(:template_name)&.underscore&.parameterize(separator: '_'),
        item.try(:class).try(:name).try(:demodulize).to_s.underscore.parameterize(separator: '_'),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/tiles/#{p}" }

      render_first_existing_partial(partials, parameters.merge({ item: item }))
    end

    def render_object_browser_partial(partial: 'tile', key:, definition:, parameters: {}, content: nil)
      partials = [
        "#{definition.dig('linked_table').try(:singularize).try(:underscore)}_#{definition.dig('template_name').try(:downcase).try(:underscore)}",
        definition.dig('linked_table').try(:singularize).try(:underscore).to_s,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/object_browser/#{p}_#{partial}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, content: content }))
    end

    def render_embedded_object_partial(partial: 'detail', key:, definition:, parameters: {}, content: nil)
      partials = [
        definition.try(:[], 'name').to_s.underscore.parameterize(separator: '_'),
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/contents/editors/embedded/#{p}_#{partial}" }

      render_first_existing_partial(partials, parameters.merge({ key: key, definition: definition, content: content }))
    end

    def render_new_content_reveal(item:, parameters: {})
      partials = [
        "#{item.class.name.demodulize.underscore}_#{item.template_name.parameterize(separator: '_')}",
        item.class.name.demodulize.underscore,
        'default'
      ].reject(&:blank?).map { |p| "data_cycle_core/application/new_contents/#{p}_content_reveal" }
      render_first_existing_partial(partials, parameters.merge({ item: item }))
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
        if value.is_a?(String)
          concat value.to_s
        elsif value.is_a?(Hash)
          concat value.map { |k, v| content_tag(:b, k.titleize + ': ') + v.join(', ') }.join(', ').html_safe
        else
          concat value.to_s
        end
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
