# frozen_string_literal: true

Faraday.default_connection = Faraday.new { |faraday|
  faraday.use DataCycleCore::FaradayRaiseExcept404
  faraday.options[:open_timeout] = 30
  faraday.options[:timeout] = 30
  faraday.adapter Faraday.default_adapter
}
