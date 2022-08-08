# frozen_string_literal: true

ActiveSupport::Notifications.subscribe('vite_asset_path_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  if Rails.env.development?
    Rails.logger.warn "asset '#{data[:content]}' not found"
  else
    Appsignal.send_error(data[:exception]) do |transaction|
      transaction.set_namespace('vite_asset_path')
      transaction.params = {
        filename: data[:content]
      }
    end
  end
end

ActiveSupport::Notifications.subscribe('faraday_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  if Rails.env.development?
    Rails.logger.warn "Error while connecting to '#{data[:target_url]}', Exception: #{data[:exception]}"
  else
    Appsignal.send_error(data[:exception]) do |transaction|
      transaction.set_namespace('faraday_error')
      transaction.params = {
        target_url: data[:target_url]
      }
    end
  end
end
