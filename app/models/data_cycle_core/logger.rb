module DataCycleCore
  class Logger
    def initialize(filename, log_to_disk = true)
      @log_to_disk = log_to_disk
      @log = Logging.logger[filename]

      if log_to_disk
        @log.add_appenders(
                Logging.appenders.stdout,
                Logging.appenders.file(Rails.root.join("log/#{filename}.log").to_s)
                )
      else
        @log.add_appenders(Logging.appenders.stdout)
      end
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
