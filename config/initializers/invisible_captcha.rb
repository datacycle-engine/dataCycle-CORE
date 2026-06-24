# frozen_string_literal: true

InvisibleCaptcha.setup do |config|
  config.timestamp_enabled = !Rails.env.test?
  config.timestamp_threshold = 2 # seconds
  config.spinner_enabled = !Rails.env.test?
  config.secret = ENV['SECRET_KEY_BASE']
end
