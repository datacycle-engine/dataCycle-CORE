# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ErrorServiceTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'rebuild keeps class, message and backtrace of a message based error' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::Generic::Common::Error::ImporterError', 'import failed', ['a.rb:1'])

      assert_instance_of DataCycleCore::Generic::Common::Error::ImporterError, error
      assert_equal 'import failed', error.message
      assert_equal ['a.rb:1'], error.backtrace
    end

    test 'rebuild accepts a class instead of a class name' do
      error = DataCycleCore::ErrorService.rebuild(DataCycleCore::Error::RecordNotFoundError, 'gone')

      assert_instance_of DataCycleCore::Error::RecordNotFoundError, error
      assert_equal 'gone', error.message
    end

    test 'rebuild falls back for errors that cannot be built from a message' do
      error = DataCycleCore::ErrorService.rebuild('Mongo::Error::NoServerAvailable', 'No PRIMARY server is available', ['a.rb:1'])

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'Mongo::Error::NoServerAvailable: No PRIMARY server is available', error.message
      assert_equal ['a.rb:1'], error.backtrace
    end

    test 'rebuild falls back for errors expecting more than one argument' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::Error::TemplateNotAllowedError', 'template missing')

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'DataCycleCore::Error::TemplateNotAllowedError: template missing', error.message
    end

    test 'rebuild falls back for errors with a failing message implementation' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::Error::WebhookError', 'webhook failed')

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'DataCycleCore::Error::WebhookError: webhook failed', error.message
    end

    test 'rebuild falls back for errors discarding the message' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::Error::BadRequestError', 'child failed')

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'DataCycleCore::Error::BadRequestError: child failed', error.message
    end

    test 'rebuild keeps the message of an unknown class' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::NotAnErrorAtAll', 'child failed')

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'DataCycleCore::NotAnErrorAtAll: child failed', error.message
    end

    test 'rebuild keeps the message of a class that must not be raised' do
      error = DataCycleCore::ErrorService.rebuild('Interrupt', 'child interrupted')

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'Interrupt: child interrupted', error.message
    end

    test 'rebuild survives an unusable backtrace' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::Error::RecordNotFoundError', 'gone', [1, 2])

      assert_instance_of DataCycleCore::Error::RecordNotFoundError, error
      assert_nil error.backtrace
    end

    test 'rebuild keeps the class name of an error without a message' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::NotAnErrorAtAll', '')

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'DataCycleCore::NotAnErrorAtAll', error.message
    end

    test 'rebuild survives a message with invalid bytes, keeping its valid characters' do
      error = DataCycleCore::ErrorService.rebuild('DataCycleCore::Error::RecordNotFoundError', "Grüße \xff".dup.force_encoding('UTF-8'), ['a.rb:1'])

      assert_instance_of DataCycleCore::Error::RecordNotFoundError, error
      assert_equal 'Grüße ', error.message
      assert_equal ['a.rb:1'], error.backtrace
    end

    test 'rebuild survives a message with invalid bytes on the fallback path' do
      error = DataCycleCore::ErrorService.rebuild('Mongo::Error::NoServerAvailable', "No PRIMARY server is available \xff".dup.force_encoding('UTF-8'))

      assert_instance_of DataCycleCore::Error::ForkedProcessError, error
      assert_equal 'Mongo::Error::NoServerAvailable: No PRIMARY server is available ', error.message
    end

    test 'rebuild ignores payloads without an error' do
      assert_nil DataCycleCore::ErrorService.rebuild(nil, nil)
      assert_nil DataCycleCore::ErrorService.rebuild(nil, '')
    end
  end
end
