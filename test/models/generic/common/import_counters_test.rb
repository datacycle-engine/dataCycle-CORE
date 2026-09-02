# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class GenericCommonImportCountersTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::ImportCounters

    IcDummyUtilityObject = Struct.new(:external_source, :step_name)

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
    end

    # the Alloy adapter subscribes to these names from its own repository
    test 'the event names of the import outcomes are stable' do
      assert_equal(
        {
          success: 'object_import_succeeded.datacycle.counter',
          failure: 'object_import_failed.datacycle.counter',
          archived: 'object_import_archived.datacycle.counter',
          deleted: 'object_import_deleted.datacycle.counter'
        },
        SUBJECT::EVENTS
      )
    end

    test 'instrument publishes the external system, step and template of the outcome' do
      events = []

      ActiveSupport::Notifications.subscribed(->(name, _s, _f, _id, payload) { events << [name, payload] }, SUBJECT::EVENTS[:archived]) do
        SUBJECT.instrument(:archived, utility_object: IcDummyUtilityObject.new(@external_source, 'archive'), template_name: 'Tour')
      end

      assert_equal(SUBJECT::EVENTS[:archived], events.first.first)
      assert_equal({ external_system: @external_source, step_name: 'archive', template_name: 'Tour' }, events.first.last)
    end

    test 'instrument raises on an unknown outcome instead of publishing a nameless event' do
      assert_raises(KeyError) do
        SUBJECT.instrument(:updated, utility_object: IcDummyUtilityObject.new(@external_source, 'update'), template_name: 'Tour')
      end
    end
  end
end
