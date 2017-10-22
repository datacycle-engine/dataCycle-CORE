module DataCycleCore
  module Generic
    class Download < DataCycleCore::Generic::DownloadBase

      def download(**options, &block)
        if options.try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new
        else
          @logging = options[:logging_strategy]
        end

        raise "Missing source_type for #{self.class.to_s}, options given: #{options}"       if options[:source_type].nil?
        raise "Missing endpoint for #{self.class.to_s}, options given: #{options}"          if options[:endpoint].nil?
        raise "Missing download_strategy for #{self.class.to_s}, options given: #{options}" if options[:download_strategy].nil?

        self.extend(options[:download_strategy])
        @source_type = options[:source_type]
        @end_point_object = options[:endpoint]

        download_content(**options)
      end

    end
  end
end
