# frozen_string_literal: true

module DataCycleCore
  module Generic
    class Download < DataCycleCore::Generic::DownloadBase
      def download(**options, &block)
        if options.try(:[], :download).try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new('download')
        else
          @logging = instance_eval(options[:download][:logging_strategy])
        end

        raise "Missing source_type for #{self.class}, options given: #{options}"       if options[:download][:source_type].nil?
        raise "Missing endpoint for #{self.class}, options given: #{options}"          if options[:download][:endpoint].nil?
        raise "Missing download_strategy for #{self.class}, options given: #{options}" if options[:download][:download_strategy].nil?

        extend(options[:download][:download_strategy].constantize)
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(@source_object, collection: options[:download][:source_type])
        @end_point_object = options[:download][:endpoint].constantize

        download_content(**options)

        @logging.close if @logging.respond_to?(:close)
      end
    end
  end
end
