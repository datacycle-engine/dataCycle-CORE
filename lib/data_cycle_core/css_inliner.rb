# frozen_string_literal: true

module DataCycleCore
  class CssInliner
    def self.delivering_email(message)
      if message.multipart?
        if message.html_part
          message.html_part.body = Premailer.new(message.html_part.body.decoded, with_html_string: true,
                                                                                 css_to_attributes: true,
                                                                                 preserve_styles: true).to_inline_css
        end
      else
        message.body = Premailer.new(message.decoded, with_html_string: true,
                                                      css_to_attributes: true,
                                                      preserve_styles: true).to_inline_css
      end

      message
    end
  end
end
