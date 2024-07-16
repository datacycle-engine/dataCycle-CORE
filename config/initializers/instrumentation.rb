# frozen_string_literal: true

ActiveSupport::Notifications.subscribe('vite_asset_path_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  Rails.logger.warn "asset '#{data[:content]}' not found" if Rails.env.development?
end

ActiveSupport::Notifications.subscribe('faraday_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  Rails.logger.warn "Error while connecting to '#{data[:target_url]}', Exception: #{data[:exception]}" if Rails.env.development?
end

ActiveSupport::Notifications.subscribe(/(download|import)_failed_repeatedly.datacycle/) do |_name, _started, _finished, _unique_id, data|
  trigger = data[:trigger].present? ? data[:trigger].to_s : 'unknown process'
  if Rails.env.development? || data[:mailing_list].blank?
    Rails.logger.warn "#{trigger.to_s.capitalize} failed repeatedly: #{data.to_json} - received mailing list: #{data[:mailing_list]}"
  else
    DataCycleCore::ExternalSystemNotificationMailer.error_notify(data[:mailing_list], trigger, data[:external_source_info], data[:exception]).deliver_now
  end
end
