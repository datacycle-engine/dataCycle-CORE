# frozen_string_literal: true

require 'minitest/hooks'

module DataCycleCore
  module TestCases
    class ActiveSupportTestCase < ActiveSupport::TestCase
      include Minitest::Hooks

      around(:all) do |&block|
        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          super(&block)
          raise ActiveRecord::Rollback
        end
      end

      setup do
        instance_variables.each do |iv|
          next unless instance_variable_get(iv).is_a?(ApplicationRecord)

          instance_variable_get(iv).reload
          instance_variable_get(iv).instance_variable_set(:@destroyed, false) if instance_variable_get(iv).destroyed?
        end
      end
    end
  end
end
