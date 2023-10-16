# frozen_string_literal: true

require 'minitest/hooks'

module DataCycleCore
  module MinitestSpecHelper
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

      around do |&block|
        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          super(&block)
        ensure
          raise ActiveRecord::Rollback
        end
      end
    end

    def assert_not(object)
      assert !object # rubocop:disable Rails/AssertNot
    end

    def assert_not_nil(object)
      assert !object.nil? # rubocop:disable Rails/AssertNot
    end
  end
end
