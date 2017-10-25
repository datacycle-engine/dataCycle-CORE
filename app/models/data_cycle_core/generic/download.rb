module DataCycleCore
  module Generic
    class Download < DataCycleCore::Generic::DownloadBase

      def download(**options, &block)
        if options.try(:[], :download).try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new('download')
        else
          @logging = instance_eval(options[:download][:logging_strategy])
        end

        raise "Missing source_type for #{self.class.to_s}, options given: #{options}"       if options[:download][:source_type].nil?
        raise "Missing endpoint for #{self.class.to_s}, options given: #{options}"          if options[:download][:endpoint].nil?
        raise "Missing download_strategy for #{self.class.to_s}, options given: #{options}" if options[:download][:download_strategy].nil?

        self.extend(options[:download][:download_strategy].constantize)
        @source_type = options[:download][:source_type].constantize
        @end_point_object = options[:download][:endpoint].constantize

        download_content(**options)
      end

    end
  end
end
