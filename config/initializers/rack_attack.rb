# frozen_string_literal: true

# Brute-force protection for the login endpoints. Active in every environment
# (including test, which has dedicated coverage for the throttling behaviour).
Rack::Attack.throttle('logins/ip', limit: 10, period: 60.seconds) do |req|
  req.ip if req.post? && ['/users/sign_in', '/api/v4/auth/login'].include?(req.path)
end

Rack::Attack.throttle('logins/email', limit: 5, period: 60.seconds) do |req|
  if req.post? && ['/users/sign_in', '/api/v4/auth/login'].include?(req.path)
    req.params['user'] ? req.params['user']['email'] : req.params['email']
  end
end

Rack::Attack.throttled_response_retry_after_header = true
