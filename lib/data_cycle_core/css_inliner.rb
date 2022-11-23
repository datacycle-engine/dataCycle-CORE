# frozen_string_literal: true

module DataCycleCore
  class CssInliner
    def self.delivering_email(message)
      transformation = lambda { |body|
        Premailer.new(
          body.decoded,
          {
            with_html_string: true,
            css_to_attributes: true,
            preserve_style_attribute: false,
            preserve_styles: true
          }
        ).to_inline_css
      }

      if message.multipart?
        message.html_part.body = transformation.call(message.html_part.body) if message.html_part
      else
        message.body = transformation.call(message.body)
      end

      message
    end
  end
end
