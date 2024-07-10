# frozen_string_literal: true

if Module.const_defined?('Rake::Task')
  raise 'Rake::Task#[] is no longer available, check patch!' unless Rake::Task.respond_to?(:[])

  module DataCycleCore
    module CoreRakePrefixExtension
      extend ActiveSupport::Concern

      class_methods do
        def [](task_name)
          task_name = "app:#{task_name}" if !task_name.starts_with?('app:') && Rake.application.top_level_tasks.any? { _1.starts_with?('app:') }

          super
        end
      end
    end
  end

  Rake::Task.prepend(DataCycleCore::CoreRakePrefixExtension)
end
