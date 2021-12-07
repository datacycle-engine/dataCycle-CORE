# frozen_string_literal: true

module DataCycleCore
  module ExceptionHelper
    def exception_title(type)
      http_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[type]
      return if http_code.blank?

      ActionView::OutputBuffer.new("<b>#{http_code}</b> #{Rack::Utils::HTTP_STATUS_CODES[http_code]}")
    end
  end
end
