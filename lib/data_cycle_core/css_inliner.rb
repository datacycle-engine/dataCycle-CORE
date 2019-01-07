# frozen_string_literal: true

module DataCycleCore
  class CssInliner
    def self.delivering_email(message)
      raise 'NotImplement' if message.multipart?

      message.body = Premailer.new(message.decoded, with_html_string: true,
                                                    css_to_attributes: true,
                                                    preserve_styles: true).to_inline_css
    end
  end
end
