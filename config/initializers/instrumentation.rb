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
