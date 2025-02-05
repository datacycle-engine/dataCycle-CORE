# frozen_string_literal: true

require 'minitest/hooks'

module DataCycleCore
  module MinitestHookHelper
    extend ActiveSupport::Concern
    include Minitest::Hooks

    included do
      around(:all) do |&block|
        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          super(&block)
        ensure
          raise ActiveRecord::Rollback
        end
      end

      # needed for config.active_job.queue_adapter = :test
      # backtrace for failures is not working correctly with this block
      # around do |&block|
      #   perform_enqueued_jobs do
      #     super(&block)
      #   end
      # end

      setup do
        instance_variables.each do |iv|
          tmp = instance_variable_get(iv)
          next unless tmp.is_a?(ApplicationRecord) && !tmp.new_record?

          tmp.instance_variable_set(:@destroyed, false) if tmp.destroyed?
          tmp.reload
        end
      end
    end
  end
end
