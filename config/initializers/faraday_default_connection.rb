# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Faraday.default_connection = Faraday.new do |faraday|
    faraday.use DataCycleCore::FaradayRaiseExcept404
    faraday.options[:open_timeout] = 30
    faraday.options[:timeout] = 30
    faraday.adapter Faraday.default_adapter
  end
end
