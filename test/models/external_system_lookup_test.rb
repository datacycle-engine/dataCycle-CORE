# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ExternalSystemLookupTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'a blank value never resolves to a system' do
      [nil, ''].each do |value|
        error = assert_raises(RuntimeError) { DataCycleCore::ExternalSystem.find_unique_by_names_identifiers_or_ids!(value) }
        assert_includes error.message, 'External system missing'
      end
    end

    test 'an unknown value raises with the value that was asked for' do
      error = assert_raises(RuntimeError) { DataCycleCore::ExternalSystem.find_unique_by_names_identifiers_or_ids!('does-not-exist') }

      assert_includes error.message, 'External system not found'
      assert_includes error.message, 'does-not-exist'
    end

    test 'a value matching two systems raises rather than picking one by row order' do
      DataCycleCore::ExternalSystem.create!(name: 'Ambiguous Alpha', identifier: 'ambiguous-key')
      DataCycleCore::ExternalSystem.create!(name: 'ambiguous-key', identifier: 'ambiguous-beta')

      error = assert_raises(RuntimeError) { DataCycleCore::ExternalSystem.find_unique_by_names_identifiers_or_ids!('ambiguous-key') }

      assert_includes error.message, 'Ambiguous external system'
      assert_includes error.message, 'Ambiguous Alpha'
    end

    test 'name, identifier and id all resolve to the same system' do
      system = DataCycleCore::ExternalSystem.create!(name: 'Unique Lookup System', identifier: 'unique-lookup-system')

      [system.name, system.identifier, system.id].each do |value|
        assert_equal system, DataCycleCore::ExternalSystem.find_unique_by_names_identifiers_or_ids!(value)
      end
    end
  end
end
