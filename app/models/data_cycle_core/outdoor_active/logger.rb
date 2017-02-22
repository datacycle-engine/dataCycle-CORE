module DataCycleCore
  module OutdoorActive

    class Logger

      def initialize(filename, log_to_disk=true)
        @log_to_disk = log_to_disk

        @log = Logging.logger[filename]
        if log_to_disk
          @loglogg.add_appenders(
                  Logging.appenders.stdout,
                  Logging.appenders.file("./log/#{filename}.log")
                  )
        else
          @log.add_appenders(Logging.appenders.stdout)
        end
        @log.level = :debug
      end

      def info(message)
        @log.info message
      end

      def error(message)
        @log.error message
      end

    end


  end
end
