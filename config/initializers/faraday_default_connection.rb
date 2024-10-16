# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Faraday.default_connection = Faraday.new do |faraday|
    faraday.use DataCycleCore::FaradayRaiseExcept404
    faraday.use FaradayMiddleware::FollowRedirects
    faraday.options[:open_timeout] = 30
    faraday.options[:timeout] = 30
    faraday.request :retry, max: 3, interval: 30, backoff_factor: 2, retry_statuses: [503, 504]
    faraday.headers['User-Agent'] = 'dataCycle'
    faraday.adapter Faraday.default_adapter
  end
end
