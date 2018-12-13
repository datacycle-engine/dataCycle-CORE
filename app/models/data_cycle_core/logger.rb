# frozen_string_literal: true

module DataCycleCore
  class Logger
    def initialize(filename, log_to_disk = true, log_to_stdout = true)
      @log_to_disk = log_to_disk
      @log = Logging.logger[filename]

      appenders = []
      appenders << Logging.appenders.stdout if log_to_stdout
      appenders << Logging.appenders.file(Rails.root.join("log/#{filename}.log").to_s) if log_to_disk
      @log.add_appenders(*appenders)

      @log.level = :debug
    end

    def info(message)
      @log.info message
    end

    def warn(message)
      @log.warn message
    end

    def error(message)
      @log.error message
    end

    def logger
      @log
    end
  end
end
