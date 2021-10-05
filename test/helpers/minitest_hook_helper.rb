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
          raise ActiveRecord::Rollback
        end
      end

      # around do |&block|
      #   ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
      #     super(&block)
      #     raise ActiveRecord::Rollback
      #   end
      # end

      setup do
        instance_variables.each do |iv|
          tmp = instance_variable_get(iv)
          next unless tmp.is_a?(ApplicationRecord)

          tmp.instance_variable_set(:@destroyed, false) if tmp.destroyed?
          tmp.reload
        end
      end
    end
  end
end
