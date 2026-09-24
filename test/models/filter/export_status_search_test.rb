# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the export_status advanced filter (#51495): the query pair on
  # Filter::Common::External that narrows contents by the status of their export syncs, which the
  # older external_system filter ignores.
  class ExportStatusSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @remote_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @failed = create_content('Artikel', { name: 'Failed' })
      @succeeded = create_content('Artikel', { name: 'Succeeded' })
      @unreported = create_content('Artikel', { name: 'Unreported' })
      create_content('Artikel', { name: 'Never exported' })
    end

    # Content::ExternalData#external_system_sync_by_system reuses a row of any sync_type for the
    # same content and system and rewrites its sync_type, so each content here gets exactly one.
    def build_export_syncs
      @failed.add_external_system_data(@local_system, { 'key' => 'value' }, 'error', 'export')
      @succeeded.add_external_system_data(@local_system, { 'key' => 'value' }, 'success', 'export')
      @unreported.add_external_system_data(@remote_system, { 'key' => 'value' }, nil, 'export')
    end

    def search(value)
      DataCycleCore::Filter::Search.new(locale: :de).export_status(value)
    end

    def not_search(value)
      DataCycleCore::Filter::Search.new(locale: :de).not_export_status(value)
    end

    def total_count
      DataCycleCore::Filter::Search.new(locale: :de).count
    end

    test 'a single status matches only the contents whose export reported it' do
      build_export_syncs

      assert_equal([@failed.id], search({ 'status' => ['error'] }).pluck(:id))
      assert_equal([@succeeded.id], search({ 'status' => ['success'] }).pluck(:id))
      assert_equal(0, search({ 'status' => ['pending'] }).count)
    end

    test 'several statuses match the union' do
      build_export_syncs

      assert_equal([@failed.id, @succeeded.id].sort, search({ 'status' => ['error', 'success'] }).pluck(:id).sort)
    end

    test "the 'nil' sentinel matches an export sync that never reported a result" do
      build_export_syncs

      assert_equal([@unreported.id], search({ 'status' => ['nil'] }).pluck(:id))
      assert_equal([@failed.id, @unreported.id].sort, search({ 'status' => ['error', 'nil'] }).pluck(:id).sort)
    end

    test 'system and status are combined, not OR-ed' do
      build_export_syncs

      assert_equal([@failed.id], search({ 'external_system_ids' => [@local_system.id], 'status' => ['error'] }).pluck(:id))
      # the error is at the local system, so the same status at the remote one matches nothing
      assert_equal(0, search({ 'external_system_ids' => [@remote_system.id], 'status' => ['error'] }).count)
    end

    test 'only export syncs are considered' do
      @failed.add_external_system_data(@local_system, { 'key' => 'value' }, 'error', 'duplicate')

      assert_equal(0, search({ 'status' => ['error'] }).count)
      assert_equal(0, search({ 'external_system_ids' => [@local_system.id], 'status' => ['error'] }).count)
    end

    # The negative mode narrows the exported contents rather than taking the complement of the
    # whole query: "exported, just not with this status". A content nobody ever exported is in
    # neither result, which is what keeps the failed-export list readable.
    test 'the negative mode keeps the export and negates only the status' do
      build_export_syncs
      value = { 'status' => ['error'] }
      negative = not_search(value).pluck(:id)

      assert_equal([@failed.id], search(value).pluck(:id))
      assert_equal([@succeeded.id, @unreported.id].sort, negative.sort)
      assert_not_includes(negative, @failed.id)
      assert_operator(search(value).count + not_search(value).count, :<, total_count)
    end

    test 'a content that was never exported is in neither result' do
      build_export_syncs
      never_exported = DataCycleCore::Thing.find_by(id: create_content('Artikel', { name: 'Untouched' }).id)

      assert_not_includes(search({ 'status' => ['success'] }).pluck(:id), never_exported.id)
      assert_not_includes(not_search({ 'status' => ['success'] }).pluck(:id), never_exported.id)
    end

    test 'the negative mode restricted to a system only considers exports to that system' do
      build_export_syncs
      value = { 'external_system_ids' => [@local_system.id], 'status' => ['error'] }

      # @unreported is exported to the remote system only, so it is outside this population
      assert_equal([@succeeded.id], not_search(value).pluck(:id))
    end

    # Systems alone ask what external_system with type 'export' already answers, so the filter
    # narrows nothing in either mode - StoredFilter.narrows_nothing? drops it from the form too.
    test 'a value carrying only systems leaves the query untouched' do
      build_export_syncs
      value = { 'external_system_ids' => [@local_system.id] }

      assert_equal(total_count, search(value).count)
      assert_equal(total_count, not_search(value).count)
    end

    test 'a blank or fully unselected value leaves the query untouched' do
      build_export_syncs

      assert_equal(total_count, search(nil).count)
      assert_equal(total_count, search({}).count)
      assert_equal(total_count, search({ 'external_system_ids' => [], 'status' => [''] }).count)
      assert_equal(total_count, not_search({ 'external_system_ids' => [], 'status' => [''] }).count)
    end

    # A stored filter's parameters are jsonb, so `v` need not be the Hash the form builds.
    # StoredFilter.narrows_nothing? reads the statuses through this same method, so no shape can
    # narrow nothing here and still be kept as a chip. A `false` status is only reachable this way -
    # through a form it arrives as the string 'false'.
    test 'a value of an unexpected shape leaves the query untouched' do
      build_export_syncs

      [['error'], 'error', { 'status' => [false] }, { 'status' => false }, [{ 'status' => ['error'] }]].each do |value|
        assert_predicate(DataCycleCore::Filter::Common::External.export_status_values(value), :blank?, "#{value.inspect} selected a status")
        assert_equal(total_count, search(value).count, "#{value.inspect} narrowed the query")
        assert_equal(total_count, not_search(value).count, "#{value.inspect} narrowed the negated query")
      end
    end

    test 'with_export_config selects the systems the filter offers' do
      exporting = DataCycleCore::ExternalSystem.create!(name: 'Exporting-System', identifier: 'exporting-system', config: { 'export_config' => { 'foo' => 'bar' } })

      assert_includes(DataCycleCore::ExternalSystem.with_export_config.pluck(:id), exporting.id)
      assert_not_includes(DataCycleCore::ExternalSystem.with_export_config.pluck(:id), @local_system.id)
    end
  end
end
