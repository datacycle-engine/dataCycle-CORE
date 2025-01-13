# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ExternalSystemSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @remote_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      create_content('Artikel', { name: 'AAA' })
      create_content('Artikel', { name: 'Bergfex1', external_key: 'bergfex1' }, @local_system.id)
      @article = create_content('Artikel', { name: 'Pimcore1', external_key: 'pimcore1' }, @remote_system.id)
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

    private

    def create_content(template_name, data = {}, external_source_id = nil)
      data = DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data)
      if external_source_id.present?
        data.external_source_id = external_source_id
        data.save
      end
      data
    end
  end
end
