module DataCycleCore
  module Generic
    class Download < DataCycleCore::Generic::DownloadBase

      def download(**options, &block)
        if options.try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new
        else
          @logging = instance_eval(options[:logging_strategy])
        end

        raise "Missing source_type for #{self.class.to_s}, options given: #{options}"       if options[:source_type].nil?
        raise "Missing endpoint for #{self.class.to_s}, options given: #{options}"          if options[:endpoint].nil?
        raise "Missing download_strategy for #{self.class.to_s}, options given: #{options}" if options[:download_strategy].nil?

        self.extend(options[:download_strategy].safe_constantize)
        @source_type = options[:source_type].safe_constantize
        @end_point_object = options[:endpoint].safe_constantize

        download_content(**options)
      end

    end
  end
end
