# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class NamedVersionTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })
    end

    test 'set_data_hash with version_name sets version name correctly' do
      version_name = 'Version 1'
      @content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, partial_update: true, version_name: version_name)

      assert_equal version_name, @content.version_name
      assert_equal version_name, @content.reload.version_name
      assert_empty @content.histories.pluck(:version_name).compact
    end

    test 'set_data_hash with version_name sets version name correctly and writes previous name to history' do
      version_name = 'Version 1'
      @content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, partial_update: true, version_name: version_name)
      @content.set_data_hash(data_hash: { name: 'Test Artikel 3' }, partial_update: true)

      assert_nil @content.version_name
      assert_equal version_name, @content.histories.first.version_name
    end

    test 'set_data_hash multiple times with verseion_name' do
      version_name1 = 'Version 1'
      version_name2 = 'Version 2'
      version_name3 = 'Version 3'
      @content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, partial_update: true, version_name: version_name1)
      @content.set_data_hash(data_hash: { name: 'Test Artikel 3' }, partial_update: true, version_name: version_name2)
      @content.set_data_hash(data_hash: { name: 'Test Artikel 4' }, partial_update: true, version_name: version_name3)

      assert_equal version_name3, @content.version_name
      assert_equal [version_name2, version_name1], @content.histories.pluck(:version_name).compact
    end
  end
end
