# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ExternalSystemSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @remote_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @no_source = create_content('Artikel', { name: 'AAA' })
      @from_local = create_content('Artikel', { name: 'Bergfex1', external_key: 'bergfex1', external_source_id: @local_system.id })
      @article = create_content('Artikel', { name: 'Pimcore1', external_key: 'pimcore1', external_source_id: @remote_system.id })
    end

    def not_search(ids, type)
      DataCycleCore::Filter::Search.new.not_external_system(ids, type).pluck(:id).sort
    end

    test 'find external_system by external_source_id in thing' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).external_system(@local_system.id).count)
      assert_equal(1, DataCycleCore::Filter::Search.new.external_system(@local_system.id, 'import').count)
    end

    test 'find external_system data by related external_system_sync' do
      external_thing_data = { 'key_1' => 'value_1' }
      @article.add_external_system_data(@local_system, external_thing_data, 'success', 'duplicate')

      assert_equal(1, DataCycleCore::Filter::Search.new.external_system(@local_system.id, 'duplicate').count)
      assert_equal(0, DataCycleCore::Filter::Search.new.external_system(@local_system.id, 'export').count)
      assert_equal(2, DataCycleCore::Filter::Search.new.external_system(@local_system.id, 'all').count)
    end

    test 'find external_system data  for exported data by external_system_sync entries' do
      external_thing_data = { 'key_1' => 'value_1' }
      @article.add_external_system_data(@local_system, external_thing_data)

      assert_equal(1, DataCycleCore::Filter::Search.new.external_system(@local_system.id, 'export').count)
      assert_equal(0, DataCycleCore::Filter::Search.new.external_system(@local_system.id, 'duplicate').count)
      assert_equal(2, DataCycleCore::Filter::Search.new.external_system(@local_system.id, 'all').count)
    end

    # The negative mode was covered only by a smoke test against a fabricated uuid
    # (filter_common_coverage_test.rb), which asserts nothing about which rows it drops.
    test 'not_external_system drops the contents whose sync carries the requested type' do
      @article.add_external_system_data(@local_system, { 'key_1' => 'value_1' }, 'success', 'export')

      assert_equal([@no_source.id, @from_local.id].sort, not_search(@local_system.id, 'export'))
      # Content::ExternalData#external_system_sync_by_system keeps one row per content and system, so
      # the export above is also the only row the duplicate mode sees - and it does not match.
      assert_equal([@no_source.id, @from_local.id, @article.id].sort, not_search(@local_system.id, 'duplicate'))
    end

    # Type 'all' negates both halves at once: the external_system_syncs row and
    # things.external_source_id. A content that was never imported has a NULL external_source_id, and
    # `external_source_id NOT IN (...)` is NULL for it rather than true, so the nil branch is the only
    # thing keeping it in the result.
    test "not_external_system with type 'all' keeps the content that has no external source" do
      @article.add_external_system_data(@local_system, { 'key_1' => 'value_1' }, 'success', 'export')

      assert_equal([@no_source.id], not_search(@local_system.id, 'all'))
    end
  end
end
