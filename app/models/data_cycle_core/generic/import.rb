module DataCycleCore
  module Generic
    class Import < DataCycleCore::Generic::ImportBase
      def import(**options, &block)
        if options.try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new
        else
          @logging = options[:logging_strategy]
        end

        raise "Missing import_strategy for #{self.class.to_s}, options given: #{options}"  if options[:import_strategy].blank?
        raise "Missing source_type for #{self.class.to_s}, options given: #{options}"      if options[:source_type].nil?
        raise "Missing data_template for #{self.class.to_s}, options given: #{options}"    if options[:data_template].blank?
        raise "Missing target_type for #{self.class.to_s}, options given: #{options}"      if options[:target_type].nil?


        self.extend(options[:import_strategy])
        @source_type = options[:source_type]
        @target_type = options[:target_type]
        @data_template = options[:data_template]

        import_data(**options)
      end

    end
  end
end
