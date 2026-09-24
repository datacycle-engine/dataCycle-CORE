# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # The guard that keeps a failure inside service_unavailable_exception from being handed back
  # to the action that just raised: rescue_from StandardError routes it to
  # internal_server_error_exception, which asks again and would divert to the same 503 view.
  class ExceptionsControllerTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      @controller = DataCycleCore::ExceptionsController.new
    end

    test 'the maintenance page is decided once, and the 500 page answers every later ask' do
      DataCycleCore::StaleProcess.stub(:stale?, true) do
        assert @controller.send(:render_maintenance_page?)
        assert_not @controller.send(:render_maintenance_page?)
      end
    end
  end
end
