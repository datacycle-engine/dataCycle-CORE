module DataCycleCore
  module ApplicationHelper

    DEFAULT_KEY_MATCHING = {
      alert:     :alert,
      notice:    :success,
      info:      :info,
      secondary: :secondary,
      success:   :success,
      error:     :alert,
      warning:   :warning,
      primary:   :primary
    }

    def display_flash_messages_new(closable: true)
      capture do
        concat "<div class='row' style='margin-top: 20px;'>".html_safe
        flash.each do |key, value|
          alert_class = DEFAULT_KEY_MATCHING[key.to_sym]
          concat alert_box(value, alert_class, closable)
        end
        concat "</div>".html_safe
      end
    end

    def display_flash_messages_resource(closable: true)
      capture do
        concat "<div class='row' style='margin-top: 20px;'>".html_safe
        resource.errors.messages.each do |value|
          text_string = "#{value[0].to_s} #{value[1][0]}"
          concat alert_box(text_string, :alert, closable)
        end
        concat "</div>".html_safe
      end

    end

    private

    def alert_box(value, alert_class, closable)
      options = { class: "flash callout #{alert_class}" }
      options[:data] = { closable: '' } if closable
      content_tag(:div, options) do
        concat "#{value}"
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
