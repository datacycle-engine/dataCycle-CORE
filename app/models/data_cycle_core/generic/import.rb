module DataCycleCore
  module Generic
    class Import < DataCycleCore::Generic::ImportBase

      def import(**options, &block)
        if options.try(:[], :import).try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new('import')
        else
          @logging = instance_eval(options[:import][:logging_strategy])
        end

        raise "Missing import_strategy for #{self.class.to_s}, options given: #{options}"  if options[:import][:import_strategy].blank?
        raise "Missing source_type for #{self.class.to_s}, options given: #{options}"      if options[:import][:source_type].nil?
        raise "Missing target_type for #{self.class.to_s}, options given: #{options}"      if options[:import][:target_type].nil?

        self.extend(options[:import][:import_strategy].constantize)
        @source_type = options[:import][:source_type].constantize
        @target_type = options[:import][:target_type].constantize
        @data_template = options[:import][:data_template]

        import_data(**options)
      end

    end
  end
end