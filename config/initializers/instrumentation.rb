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

# logger for importers
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
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: data&.dig(:type) || 'download') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('object_template_converted.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    logger.dc_log(:info, data)
  end
end

ActiveSupport::Notifications.subscribe('object_template_conversion_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    logger.dc_log(:error, data)
  end
end

# An import run rejected items whose template_name this instance does not know - e.g. a
# legacy template removed here while the remote still delivers it. Not an error: the run
# completed, the items were skipped. The payload carries one aggregated report per run.
ActiveSupport::Notifications.subscribe('object_template_rejected.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    logger.dc_log(:warn, data)
  end
end

ActiveSupport::Notifications.subscribe(/(download|dump|mark_deleted)_failed.datacycle/) do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'download') do |logger|
    data[:external_system]&.check_for_repeated_failure('download', data[:exception], data[:step_name])
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('import_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    data[:external_system]&.check_for_repeated_failure('import', data[:exception], data[:step_name])
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('webhooks_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'webhooks') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('duplicate_merge_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'datacycle') do |logger|
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

ActiveSupport::Notifications.subscribe('export_job_status.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'export') do |logger|
    severity = data[:severity]&.to_sym || :info
    logger.dc_log(severity, data)
  end
end

ActiveSupport::Notifications.subscribe('asset_version_generation_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  Rails.logger.warn "Asset #{data[:version]} version generation failed for ##{data[:asset].id}: #{data[:exception].message}" if Rails.env.development?
end

ActiveSupport::Notifications.subscribe('object_import_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'import') do |logger|
    logger.dc_log(:error, data)
  end
end

# A single item a download step could not write. Not part of the (download|dump|mark_deleted)_failed
# group: the step itself did not fail, so it must not reach check_for_repeated_failure.
# Logger::Instrumentation#item_failed is not download-only -- it takes the channel as an argument --
# so the payload's own kind decides the log file, as it does for job_failed above.
ActiveSupport::Notifications.subscribe('download_item_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: data[:type].presence || 'download') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe(/(download|import|export)_faulty_items_processing_report.datacycle/) do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: data[:namespace]) do |logger|
    data[:faulty_items].each do |faulty_item|
      text = faulty_item[:log_message].presence || faulty_item.to_json
      logger.dc_log(:warn, text)
    end
  end
end

ActiveSupport::Notifications.subscribe('object_browser.stored_filter.unknown') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'datacycle') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe('feratel_deskline_organisation_access_denied.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'datacycle') do |logger|
    logger.dc_log(:warn, data)
  end
end

ActiveSupport::Notifications.subscribe('migration_failed.datacycle') do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'datacycle') do |logger|
    logger.dc_log(:error, data)
  end
end

ActiveSupport::Notifications.subscribe(/\A(error|failure)\.active_job\z/) do |_name, _started, _finished, _unique_id, data|
  DataCycleCore::Loggers::InstrumentationLogger.with_logger(type: 'jobs') do |logger|
    logger.dc_log(:error, data)
  end
end
