# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module RunRakeTask
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.logging_without_mongo(
            utility_object:,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        def self.process_content(_utility_object, options) # rubocop:disable Naming/PredicateMethod
          rake_task = options.dig(:import, :rake_task) || options.dig(:download, :rake_task)
          rake_args = options.dig(:import, :rake_args) || options.dig(:download, :rake_args)

          raise 'Rake task not found' if rake_task.blank? || Rake::Task[rake_task].nil?

          Rake::Task[rake_task].invoke(*rake_args)
          Rake::Task[rake_task].reenable
          # success
          true
        end

        def self.source_type?
          false
        end
      end
    end
  end
end
