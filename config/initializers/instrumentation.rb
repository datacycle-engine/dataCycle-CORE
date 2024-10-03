# frozen_string_literal: true

ActiveSupport::Notifications.subscribe('vite_asset_path_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  Rails.logger.warn "asset '#{data[:content]}' not found" if Rails.env.development?
end

ActiveSupport::Notifications.subscribe('faraday_error.datacycle') do |_name, _started, _finished, _unique_id, data|
  Rails.logger.warn "Error while connecting to '#{data[:target_url]}', Exception: #{data[:exception]}" if Rails.env.development?
end

ActiveSupport::Notifications.subscribe(/(download|import)_failed_repeatedly.datacycle/) do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::ExternalSystemNotificationMailer.error_notify(
    data[:mailing_list],
    data[:type],
    data[:external_system],
    data[:exception]&.message,
    data[:exception]&.backtrace&.first(20)
  ).deliver_later
end

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
end

ActiveSupport::Notifications.subscribe(/.*job_failed.datacycle/) do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'download') do |logger|
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
    data[:external_system]&.check_for_repeated_failure('download', data[:exception])
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('import_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    data[:external_system]&.check_for_repeated_failure('import', data[:exception])
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
