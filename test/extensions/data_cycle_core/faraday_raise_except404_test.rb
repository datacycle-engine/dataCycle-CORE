# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FaradayRaiseExcept404Test < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'does not raise for a 404 response' do
      middleware = DataCycleCore::FaradayRaiseExcept404.new(->(env) { env })
      env = Object.new
      env.define_singleton_method(:[]) { |key| key == :status ? 404 : nil }

      assert_nil middleware.on_complete(env)
    end
  end
end
