module DataCycleCore

  module HistoryModule
    def self.included(base)
      puts " ---> HistoryModule self.included(#{base})"
      base.extend ClassMethods
    end

    module ClassMethods
      def historizable(options={}, &block)
        return if self.included_modules.include? DataCycleCore::HistoryModule::InstanceMethods
        __send__ :include, DataCycleCore::HistoryModule::InstanceMethods

        cattr_accessor :history_class_name, :history_foreign_key, :history_table_name, :version_column

        self.history_class_name         = options[:class_name] || 'History'
        self.history_foreign_key        = options[:foreign_key] || 'creative_work_id'
        self.history_table_name         = options[:table_name] || 'creative_work_histories'
        self.version_column             = options[:version_column] || 'updated_at'

        # Setup histories association
        class_eval do
          has_many :histories, :class_name  => history_class_name,
                              :foreign_key => history_foreign_key
        end

      end
    end

    module InstanceMethods
      def hello
        "Hello World!"
      end
    end

  end
end
