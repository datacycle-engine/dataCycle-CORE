# frozen_string_literal: true

# Brute-force protection for the login endpoints. Active in every environment
# (including test, which has dedicated coverage for the throttling behaviour).
login_paths = ['/users/sign_in', '/api/v4/auth/login']

Rack::Attack.throttle('logins/ip', limit: 10, period: 60.seconds) do |req|
  req.ip if req.post? && login_paths.include?(req.path)
end

Rack::Attack.throttle('logins/email', limit: 5, period: 60.seconds) do |req|
  if req.post? && login_paths.include?(req.path)
    req.params['user'] ? req.params['user']['email'] : req.params['email']
  end
end

# API clients parse { errors: [{ detail: ... }] } and have nothing to show for rack-attack's default
# text/plain body, so a throttled login surfaces as an unknown error rather than as "too many
# attempts". Browser sign in keeps the plain text response.
Rack::Attack.throttled_responder = lambda do |req|
  match_data = req.env['rack.attack.match_data']
  retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])
  headers = { 'retry-after' => retry_after.to_s }

  next [429, headers.merge('content-type' => 'text/plain'), ["Retry later\n"]] unless req.path.start_with?('/api/')

  [
    429,
    headers.merge('content-type' => 'application/json'),
    [{ errors: [{ source: { pointer: req.path }, detail: 'too_many_requests' }] }.to_json]
  ]
end
