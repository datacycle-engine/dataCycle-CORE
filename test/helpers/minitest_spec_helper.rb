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

    # add some assertions that are not included in minitest/spec but are used in the tests
    def assert_not(object)
      assert !object # rubocop:disable Rails/AssertNot,Minitest/RefuteFalse
    end

    def assert_not_nil(object)
      assert !object.nil? # rubocop:disable Rails/AssertNot,Minitest/RefuteFalse
    end

    def assert_not_equal(expected, actual)
      assert expected != actual # rubocop:disable Minitest/AssertOperator,Minitest/RefuteEqual
    end

    def assert_kind_of(klass, object)
      assert object.is_a?(klass)
    end
  end
end
