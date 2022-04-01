# frozen_string_literal: true

ActiveSupport::Notifications.subscribe('vite_asset_path_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  Rails.logger.warn "asset '#{data[:content]}' not found" if Rails.env.development?
end

ActiveSupport::Notifications.subscribe('faraday_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  Rails.logger.warn "Error while connecting to '#{data[:target_url]}', Exception: #{data[:exception]}" if Rails.env.development?
end
