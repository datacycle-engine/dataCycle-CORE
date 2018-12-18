# frozen_string_literal: true

module DataCycleCore
  class CssInliner
    def self.delivering_email(message)
      raise 'NotImplement' if message.multipart?

      message.body = Premailer.new(message.decoded, with_html_string: true).to_inline_css
    end
  end
end
