# frozen_string_literal: true

require 'minitest/hooks'

module DataCycleCore
  module TestCases
    class ActiveSupportTestCase < ActiveSupport::TestCase
      include Minitest::Hooks

      around(:all) do |&block|
        ActiveRecord::Base.transaction do
          super(&block)
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
