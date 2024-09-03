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

# BEGIN: Logging Instrumentation Handling

ActiveSupport::Notifications.subscribe('instrumentation_logging.datacycle') do |_name, _started, _finished, _unique_id, data|
  log_methods = {
    'error' => :error,
    'failure' => :error,
    'warning' => :warn,
    'debug' => :debug
  }

  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: data[:type]) do |logger|
    logger.dc_log(log_methods[data[:severity]], data)
  end

  if data[:trigger_appsignal]
    Appsignal.send_error(data[:exception] || data[:message]) do |transaction|
      transaction.set_namespace("#{data[:type]} job failed - #{data[:external_system]}")
    end
  end
end

ActiveSupport::Notifications.subscribe(/.*job_failed.datacycle/) do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'download') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('object_import_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('object_import_failed_template.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe(/(download|dump|mark_deleted)_failed.datacycle/) do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'download') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('webhooks_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'webhooks') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('deprecation.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'datacycle') do |logger|
    logger.dc_log(:warn, data)
  end
end

ActiveSupport::Notifications.subscribe('vite_asset_path_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'webhooks') do |logger|
    logger.dc_log(:warn, data)
  end
end

ActiveSupport::Notifications.subscribe('faraday_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'faraday') do |logger|
    logger.dc_log(:error, data)
  end
end
