# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class NamedVersionTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })
      @version_name2 = 'Version 2'
      @content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, partial_update: true, version_name: @version_name2)
      @content.set_data_hash(data_hash: { name: 'Test Artikel 3' }, partial_update: true)
      @version_name4 = 'Version 4'
      @content.set_data_hash(data_hash: { name: 'Test Artikel 4' }, partial_update: true, version_name: @version_name4)
    end

    test 'set_data_hash with version_name sets version name correctly' do
      assert_equal @version_name4, @content.version_name
      assert_equal @version_name4, @content.reload.version_name
      assert_equal [@version_name2], @content.histories.pluck(:version_name).compact
    end

    test 'set_data_hash with version_name sets version name correctly and writes previous name to history' do
      @content.set_data_hash(data_hash: { name: 'Test Artikel 5' }, partial_update: true)

      assert_nil @content.version_name
      assert_nil @content.reload.version_name
      assert_equal [@version_name4, @version_name2], @content.histories.pluck(:version_name).compact
    end

    test 'set_data_hash multiple times with version_name' do
      assert_equal @version_name4, @content.version_name
      assert_equal [@version_name2], @content.histories.pluck(:version_name).compact
    end

    test 'named_histories returns all named histories' do
      assert_equal 1, @content.named_histories.size
      assert_equal [@version_name2], @content.named_histories.pluck(:version_name)
    end

    test 'previous_named_history returns correct history' do
      assert_equal @version_name2, @content.previous_named_history.version_name

      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 10' }, prevent_history: true)
      assert_nil content2.previous_named_history

      content2.set_data_hash(data_hash: { name: 'Test Artikel 11' }, partial_update: true)
      content2.set_data_hash(data_hash: { name: 'Test Artikel 12' }, partial_update: true)
      assert_equal content2.histories.last.id, content2.previous_named_history.id

      content2.set_data_hash(data_hash: { name: 'Test Artikel 13' }, partial_update: true, version_name: 'Version 1')
      assert_equal content2.histories.last.id, content2.previous_named_history.id

      content2.set_data_hash(data_hash: { name: 'Test Artikel 14' }, partial_update: true)
      assert_equal content2.histories.first.id, content2.previous_named_history.id
    end
  end
end
