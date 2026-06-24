# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class IdSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      remote_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      create_content('Artikel', { name: 'AAA' })
      @article_bergfex = create_content('Artikel', { name: 'Bergfex1', external_key: 'bergfex1', external_source_id: @local_system.id })
      @article_remote_system = create_content('Artikel', { name: 'remote_system1', external_key: 'remote_system1', external_source_id: remote_system.id })
    end

    test 'find by internal id (thing.id)' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => @article_remote_system.id }, 'internal').count)
    end

    test 'cannot find by internal id when for external_key searched (thing.external_key)' do
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => @article_remote_system.id }, 'external').count)
    end

    test 'find by external id (thing.external_key)' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => 'remote_system1' }, 'external').count)
    end

    test 'cannot find by external id when external_key given(thing.external_key)' do
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => 'remote_system1' }, 'internal').count)
    end

    test 'all finds internal as well as external ids' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => @article_remote_system.id }, 'all').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => 'remote_system1' }, 'all').count)
    end

    test 'external also finds external_keys in external_system_syncs' do
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => 'Bergfex2' }, 'all').count)
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => 'Bergfex2' }, 'external').count)
      @article_remote_system.add_external_system_data(@local_system, nil, 'success', 'duplicate', 'Bergfex2')

      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => 'Bergfex2' }, 'all').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).id({ 'text' => 'Bergfex2' }, 'external').count)
    end

    test 'find by partial internal id (thing.id)' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => @article_remote_system.id.to_s.first(20) }, 'internal').count)
    end

    test 'cannot find by partial internal id when for external_key searched (thing.external_key)' do
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => @article_remote_system.id.to_s.first(20) }, 'external').count)
    end

    test 'find by partial external id (thing.external_key)' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => 'remote_sy' }, 'external').count)
    end

    test 'cannot find by partial external id when external_key given(thing.external_key)' do
      assert_equal(0, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => 'remote_sy' }, 'internal').count)
    end

    test 'all finds partial internal as well as external ids' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => @article_remote_system.id.to_s.first(20) }, 'all').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => 'remote_sy' }, 'all').count)
    end

    test 'external also finds partial external_keys in external_system_syncs' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => 'Berg' }, 'all').count)
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => 'Berg' }, 'external').count)
      @article_remote_system.add_external_system_data(@local_system, nil, 'success', 'duplicate', 'Bergfex2')

      assert_equal(2, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => 'Berg' }, 'all').count)
      assert_equal(2, DataCycleCore::Filter::Search.new(locale: :de).like_id({ 'text' => 'Berg' }, 'external').count)
    end
  end
end
