module DataCycleCore
  module Generic
    class Import < DataCycleCore::Generic::ImportBase
      def import(**options, &block)
        if options.try(:[], :import).try(:[], :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new('import')
        else
          @logging = instance_eval(options[:import][:logging_strategy])
        end

        raise "Missing import_strategy for #{self.class}, options given: #{options}"  if options[:import][:import_strategy].blank?
        raise "Missing source_type for #{self.class}, options given: #{options}"      if options[:import][:source_type].nil?
        raise "Missing target_type for #{self.class}, options given: #{options}"      if options[:import][:target_type].nil?

        extend(options[:import][:import_strategy].constantize)
        @options = options
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(@source_object, collection: options[:import][:source_type])
        @target_type = options[:import][:target_type].constantize
        @data_template = options[:import][:data_template]

        import_data(**options)

        @logging.close if @logging.respond_to?(:close)
      end
    end
  end
end
