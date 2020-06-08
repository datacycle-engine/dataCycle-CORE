# frozen_string_literal: true

CarrierWave.configure do |config|
  # These permissions will make dir and files available only to the user running
  # the servers
  config.permissions = 0o777
  config.directory_permissions = 0o777
  config.storage = :file
  # This avoids uploaded files from saving to public/ and so
  # they will not be available for public (non-authenticated) downloading
  # config.root = Rails.root.join("private")
  config.asset_host = ActionController::Base.asset_host
  config.enable_processing = false if Rails.env.test?
end
