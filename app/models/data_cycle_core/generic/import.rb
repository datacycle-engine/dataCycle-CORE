# frozen_string_literal: true

# TODO: delete after refactor !!
module DataCycleCore
  module Generic
    class Import < ImportBase
      attr_reader :options, :logging, :source_type, :source_object

      def import(**options, &block)
        if options.dig(:import, :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new('import')
        else
          @logging = instance_eval(options[:import][:logging_strategy])
        end

        raise "Missing import_strategy for #{self.class}, options given: #{options}"  if options[:import][:import_strategy].blank?
        raise "Missing source_type for #{self.class}, options given: #{options}"      if options[:import][:source_type].nil?

        extend(options[:import][:import_strategy].constantize)
        @options = options.with_indifferent_access
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(@source_object, collection: options[:import][:source_type])

        import_data(**options)
      ensure
        logging.close if logging.respond_to?(:close)
      end
    end
  end
end
