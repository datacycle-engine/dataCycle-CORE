# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Faraday.default_connection = Faraday.new do |faraday|
    faraday.use DataCycleCore::FaradayRaiseExcept404
    faraday.request :retry, max: 3, interval: 30, backoff_factor: 2, retry_statuses: [503, 504]
    faraday.response :follow_redirects, limit: 5, standards_compliant: true
    faraday.options[:open_timeout] = 30
    faraday.options[:timeout] = 30
    faraday.headers['User-Agent'] = DataCycleCore.http_user_agent
    faraday.adapter Faraday.default_adapter
  end
end
