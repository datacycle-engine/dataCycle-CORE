# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Hardening for the intermittent RespondToMismatchError / DoubleRenderError:
  # once the response has already been rendered (e.g. an exception raised in an
  # `after_action`), the `rescue_from` handlers must not try to render/respond
  # again. Every responder short-circuits on `performed?`.
  class ErrorHandlerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    class FakeController < ActionController::API
      include ActionController::MimeResponds
      include DataCycleCore::ErrorHandler
    end

    setup do
      @controller = FakeController.new
    end

    def api_error_double
      struct_double(data: [])
    end

    test 'respond_to based handlers do not respond once the response is performed' do
      @controller.stub(:performed?, true) do
        @controller.stub(:respond_to, ->(*) { flunk('respond_to must not run after the response is committed') }) do
          assert_nil @controller.send(:bad_request, ActionController::BadRequest.new)
          assert_nil @controller.send(:bad_request_error, struct_double(formatted_errors: []))
          assert_nil @controller.send(:not_found, ActiveRecord::RecordNotFound.new)
          assert_nil @controller.send(:conflict, ActiveRecord::RecordNotUnique.new('dup'))
          assert_nil @controller.send(:redirect_to_root_with_error, RuntimeError.new, :forbidden)
          assert_nil @controller.send(:user_interface_error, RuntimeError.new)
        end
      end
    end

    test 'render and head based handlers do not respond once the response is performed' do
      @controller.stub(:performed?, true) do
        @controller.stub(:render, ->(*) { flunk('render must not run after the response is committed') }) do
          @controller.stub(:head, ->(*) { flunk('head must not run after the response is committed') }) do
            assert_nil @controller.send(:bad_request_api_error, api_error_double)
            assert_nil @controller.send(:expired_content_api_error, api_error_double)
            assert_nil @controller.send(:not_acceptable)
            assert_nil @controller.send(:too_many_requests)
          end
        end
      end
    end

    test 'the guard leaves the normal (not yet performed) path untouched' do
      head_calls = []

      @controller.stub(:performed?, false) do
        @controller.stub(:head, ->(*args) { head_calls << args }) do
          @controller.send(:too_many_requests)
        end
      end

      assert_equal 1, head_calls.size
    end
  end
end
