# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class Utf8CleanerMiddlewareTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'passes the sanitized env through to the app' do
      received = nil
      middleware = DataCycleCore::Utf8CleanerMiddleware.new(lambda { |env|
        received = env
        [200, {}, ['ok']]
      })

      status, = middleware.call(Rack::MockRequest.env_for('/'))

      assert_equal 200, status
      assert received
    end

    test 'returns a 400 response when the app raises an encoding error' do
      middleware = DataCycleCore::Utf8CleanerMiddleware.new(->(_env) { raise Encoding::UndefinedConversionError })

      assert_equal [400, {}, ['Bad Request']], middleware.call(Rack::MockRequest.env_for('/'))
    end
  end
end
