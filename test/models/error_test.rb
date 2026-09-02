# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Error
    class ErrorTest < DataCycleCore::TestCases::ActiveSupportTestCase
      test 'WebhookError formats request/response details from the original error' do
        body = (1..25).map { |i| "line #{i}" }.join("\n")
        original = struct_double(
          message: 'boom',
          response: {
            request: { method: 'POST', url_path: '/hook', body: 'payload' },
            status: 500,
            body:
          },
          backtrace: (1..10).map { |i| "frame #{i}" }
        )
        error = DataCycleCore::Error::WebhookError.new(original)
        message = error.message

        assert_includes(message, 'boom')
        assert_includes(message, 'request_method: POST')
        assert_includes(message, 'request_url_path: /hook')
        assert_includes(message, 'response_status: 500')
        assert_includes(message, 'MORE: + 5 lines')
        assert_equal(5, error.backtrace.size)
      end

      test 'WebhookError without an original error falls back to self' do
        error = DataCycleCore::Error::WebhookError.new(nil)

        assert_equal(error, error.original_error)
      end

      # `#message` and `#backtrace` both delegate to `original_error`, which is the error itself
      # here — without the guard they would recurse until SystemStackError
      test 'WebhookError without an original error renders itself without recursing' do
        error = DataCycleCore::Error::WebhookError.new(nil)

        assert_nothing_raised { error.message }
        assert_nothing_raised { error.backtrace }
      end

      test 'describe names the exception class in front of its message' do
        assert_equal('RuntimeError: boom', DataCycleCore::Error.describe(RuntimeError.new('boom')))
      end

      test 'describe does not repeat the class name of a message-less exception' do
        assert_equal('ArgumentError', DataCycleCore::Error.describe(ArgumentError.new))
      end

      # `to_s` and not `message`, so no overridden `#message` can make the reporting path the thing
      # that fails. WebhookError is the wrong subject for this: its own guard makes the two agree.
      class HostileMessageError < StandardError
        def message
          raise NotImplementedError, 'message is not usable here'
        end
      end

      test 'describe renders an exception whose message cannot be called' do
        assert_equal(
          'DataCycleCore::Error::ErrorTest::HostileMessageError: real detail',
          DataCycleCore::Error.describe(HostileMessageError.new('real detail'))
        )
      end

      test 'ApiCacheReadError serializes cache key and content' do
        error = DataCycleCore::Error::ApiCacheReadError.new(cache_key: 'graph:1', cache_content: { a: 1 })

        assert_equal('graph:1', error.cache_key)
        assert_includes(error.message, 'cache_key: graph:1')
        assert_includes(error.message, 'cache_content:')
        assert_nil(error.backtrace)
      end

      test 'Filter::DateFilterRangeError exposes a fixed message and the date range' do
        error = DataCycleCore::Error::Filter::DateFilterRangeError.new(['2020-01-01', '2019-01-01'])

        assert_equal('2020-01-01', error.start_date)
        assert_equal('2019-01-01', error.end_date)
        assert_includes(error.message, 'end date must be equal or greater')
      end

      test 'Filter::FilterRecursionError has a fixed message' do
        assert_includes(DataCycleCore::Error::Filter::FilterRecursionError.new.message, 'infinite recursion')
      end

      test 'BadRequestError#formatted_errors handles dry messages and plain hashes' do
        dry_message = Dry::Schema.Params { required(:name).filled }.call({}).errors.first
        error = DataCycleCore::Error::BadRequestError.new([dry_message, { path: 'email', message: 'is invalid' }])
        formatted = error.formatted_errors

        assert_equal(2, formatted.size)
        assert_equal('email', formatted.last[:source][:parameter])
        assert_predicate(formatted.first[:detail], :present?)
      end
    end
  end
end
